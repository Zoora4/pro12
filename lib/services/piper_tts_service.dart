import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

// ── Engine enum ───────────────────────────────────────────────
enum TtsEngine { piper, flutterTts }

// ── Piper Voice model definition ──────────────────────────────
class VoiceModel {
  final String id;
  final String label;
  final String accent;
  final String assetOnnx;
  final String assetJson;

  const VoiceModel({
    required this.id,
    required this.label,
    required this.accent,
    required this.assetOnnx,
    required this.assetJson,
  });
}

const List<VoiceModel> availableVoices = [
  VoiceModel(
    id: 'lessac',
    label: 'Lessac',
    accent: 'en-US',
    assetOnnx: 'assets/models/en_US-lessac-medium.onnx',
    assetJson: 'assets/models/en_US-lessac-medium.onnx.json',
  ),
  VoiceModel(
    id: 'alan',
    label: 'Alan',
    accent: 'en-GB',
    assetOnnx: 'assets/models/en_GB-alan-medium.onnx',
    assetJson: 'assets/models/en_GB-alan-medium.onnx.json',
  ),
  VoiceModel(
    id: 'amy',
    label: 'Amy',
    accent: 'en-US',
    assetOnnx: 'assets/models/en_US-amy-medium.onnx',
    assetJson: 'assets/models/en_US-amy-medium.onnx.json',
  ),
];

// ── Flutter TTS voice entry ───────────────────────────────────
class FlutterTtsVoice {
  final String id;
  final String label;
  final String locale;
  final Map<String, String> raw;

  const FlutterTtsVoice({
    required this.id,
    required this.label,
    required this.locale,
    required this.raw,
  });
}

// ── Isolate message types ─────────────────────────────────────
class _TtsRequest {
  final String text;
  final double speed;
  final int id;
  const _TtsRequest(this.text, this.speed, this.id);
}

class _TtsResponse {
  final Uint8List? bytes;
  final int id;
  const _TtsResponse(this.bytes, this.id);
}

class _InitRequest {
  final String modelPath;
  final String tokensPath;
  final String espeakDir;
  final SendPort replyPort;
  const _InitRequest(
      this.modelPath, this.tokensPath, this.espeakDir, this.replyPort);
}

// ── Piper isolate entry ───────────────────────────────────────
void _ttsIsolateEntry(SendPort mainSendPort) {
  final receivePort = ReceivePort();
  mainSendPort.send(receivePort.sendPort);

  sherpa.OfflineTts? tts;

  receivePort.listen((message) {
    if (message is _InitRequest) {
      try {
        sherpa.initBindings();
        tts = sherpa.OfflineTts(sherpa.OfflineTtsConfig(
          model: sherpa.OfflineTtsModelConfig(
            vits: sherpa.OfflineTtsVitsModelConfig(
              model: message.modelPath,
              tokens: message.tokensPath,
              dataDir: message.espeakDir,
              noiseScale: 0.667,
              noiseScaleW: 0.8,
              lengthScale: 1.0,
            ),
            numThreads: 4,
            debug: false,
            provider: 'cpu',
          ),
          ruleFsts: '',
        ));
        message.replyPort.send('ready');
      } catch (e) {
        message.replyPort.send('error:$e');
      }
    } else if (message is _TtsRequest) {
      if (tts == null) {
        mainSendPort.send(_TtsResponse(null, message.id));
        return;
      }
      try {
        final audio = tts!.generate(
          text: message.text,
          sid: 0,
          speed: message.speed,
        );
        final bytes = _samplesToWavBytes(audio.samples, audio.sampleRate);
        mainSendPort.send(_TtsResponse(bytes, message.id));
      } catch (e) {
        debugPrint('TTS isolate generate error: $e');
        mainSendPort.send(_TtsResponse(null, message.id));
      }
    }
  });
}

// ── Persistent isolate manager ────────────────────────────────
class _IsolateManager {
  Isolate? _isolate;
  SendPort? _sendPort;
  ReceivePort? _receivePort;
  bool _ready = false;

  final Map<int, Completer<Uint8List?>> _pending = {};
  int _nextId = 0;

  Future<void> spawn(
      String modelPath, String tokensPath, String espeakDir) async {
    await kill();

    _receivePort = ReceivePort();
    _isolate = await Isolate.spawn(_ttsIsolateEntry, _receivePort!.sendPort);

    final initCompleter = Completer<bool>();

    _receivePort!.listen((message) {
      if (message is SendPort) {
        _sendPort = message;
        final replyPort = ReceivePort();
        replyPort.listen((reply) {
          replyPort.close();
          if (reply == 'ready') {
            _ready = true;
            initCompleter.complete(true);
          } else {
            debugPrint('TTS isolate init failed: $reply');
            initCompleter.complete(false);
          }
        });
        _sendPort!.send(
            _InitRequest(modelPath, tokensPath, espeakDir, replyPort.sendPort));
      } else if (message is _TtsResponse) {
        final completer = _pending.remove(message.id);
        completer?.complete(message.bytes);
      }
    });

    await initCompleter.future;
  }

  Future<Uint8List?> generate(String text, double speed) async {
    if (!_ready || _sendPort == null) return null;
    final id = _nextId++;
    final completer = Completer<Uint8List?>();
    _pending[id] = completer;
    _sendPort!.send(_TtsRequest(text, speed, id));
    return completer.future;
  }

  void cancelAll() {
    for (final c in _pending.values) {
      if (!c.isCompleted) c.complete(null);
    }
    _pending.clear();
  }

  Future<void> kill() async {
    cancelAll();
    _ready = false;
    _receivePort?.close();
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _sendPort = null;
    _receivePort = null;
  }
}

// ── Main TTS service ──────────────────────────────────────────
class PiperTtsService {
  static final PiperTtsService _instance = PiperTtsService._internal();
  factory PiperTtsService() => _instance;
  PiperTtsService._internal();

  // ── Ping-pong: two players + two files ───────────────────────
  final AudioPlayer _playerA = AudioPlayer();
  final AudioPlayer _playerB = AudioPlayer();
  File? _fileA;
  File? _fileB;
  bool _slotA = true;

  AudioPlayer get _currentPlayer => _slotA ? _playerA : _playerB;
  File? get _currentFile => _slotA ? _fileA : _fileB;
  AudioPlayer get _nextPlayer => _slotA ? _playerB : _playerA;
  File? get _nextFile => _slotA ? _fileB : _fileA;

  final _IsolateManager _isolate = _IsolateManager();

  final FlutterTts _fTts = FlutterTts();
  List<FlutterTtsVoice> _fTtsVoices = [];
  FlutterTtsVoice? _activeFTtsVoice;
  bool _fTtsInitialized = false;

  bool _initialized = false;
  Future<void>? _initFuture;

  late String _tokensPath;
  late String _espeakDir;
  late String _modelDir;

  TtsEngine _engine = TtsEngine.piper;
  TtsEngine get engine => _engine;

  VoiceModel _activeVoice = availableVoices.first;
  VoiceModel get activeVoice => _activeVoice;

  List<FlutterTtsVoice> get flutterTtsVoices =>
      List.unmodifiable(_fTtsVoices);
  FlutterTtsVoice? get activeFTtsVoice => _activeFTtsVoice;

  double _currentPitch = 1.0;
  double get currentPitch => _currentPitch;

  // ── Loop control ──────────────────────────────────────────────
  int _loopGen = 0;
  bool _loopRunning = false;

  // FIX 3: Store the active onFinished callback so stopLoop() can always
  // fire it, even when the loop exits mid-sentence due to engine/voice switch.
  void Function(bool)? _activeOnFinished;

  // ── Init ──────────────────────────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;
    _initFuture ??= _doInit();
    await _initFuture;
  }

  Future<void> _doInit() async {
    debugPrint('=== PiperTtsService: init started ===');
    final dir = await getApplicationDocumentsDirectory();
    _modelDir = '${dir.path}/tts_model';
    final espeakDir = '$_modelDir/espeak-ng-data';

    final modelDirObj = Directory(_modelDir);
    if (await modelDirObj.exists()) {
      await modelDirObj.delete(recursive: true);
    }
    await Directory(_modelDir).create(recursive: true);
    await Directory(espeakDir).create(recursive: true);

    _tokensPath = await _copyAsset(
        'assets/models/tokens.txt', '$_modelDir/tokens.txt');

    for (final voice in availableVoices) {
      final fileName = voice.assetOnnx.split('/').last;
      final jsonName = voice.assetJson.split('/').last;
      await _copyAsset(voice.assetOnnx, '$_modelDir/$fileName');
      await _copyAsset(voice.assetJson, '$_modelDir/$jsonName');
    }

    await _copyAssetFolder('assets/models/espeak-ng-data/', espeakDir);
    _espeakDir = espeakDir;

    final defaultOnnx =
        '$_modelDir/${availableVoices.first.assetOnnx.split('/').last}';
    await _isolate.spawn(defaultOnnx, _tokensPath, _espeakDir);

    final tmpDir = await getTemporaryDirectory();
    _fileA = File('${tmpDir.path}/piper_out_a.wav');
    _fileB = File('${tmpDir.path}/piper_out_b.wav');
    for (final f in [_fileA!, _fileB!]) {
      if (!await f.exists()) await f.create();
    }

    for (final p in [_playerA, _playerB]) {
      p.playbackEventStream.listen(
        (_) {},
        onError: (e, st) => debugPrint('Player error: $e'),
      );
    }

    await _checkIsolateHealth();
    _initFlutterTts();

    _initialized = true;
    debugPrint('=== PiperTtsService: ready ===');
  }

  Future<void> _checkIsolateHealth() async {
    final bytes = await _isolate.generate('test', 1.0);
    debugPrint('=== Isolate health check: ${bytes?.length ?? 0} bytes ===');
  }

  Future<void> _initFlutterTts() async {
    try {
      await _fTts.setLanguage('en-US');
      await _fTts.setSpeechRate(0.5);
      await _fTts.setVolume(1.0);
      await _fTts.setPitch(1.0);

      final rawVoices = await _fTts.getVoices;
      if (rawVoices == null) return;

      final voices = <FlutterTtsVoice>[];
      for (final v in rawVoices) {
        if (v is Map) {
          final locale = (v['locale'] ?? '').toString();
          final name = (v['name'] ?? '').toString();
          if (!locale.toLowerCase().startsWith('en')) continue;
          if (name.isEmpty) continue;
          final label = _friendlyVoiceName(name, locale);
          voices.add(FlutterTtsVoice(
            id: name,
            label: label,
            locale: locale,
            raw: {
              for (final e in v.entries)
                e.key.toString(): e.value.toString()
            },
          ));
        }
      }

      voices.sort((a, b) {
        int priority(String loc) {
          if (loc.startsWith('en-US')) return 0;
          if (loc.startsWith('en-GB')) return 1;
          return 2;
        }
        final p = priority(a.locale).compareTo(priority(b.locale));
        if (p != 0) return p;
        return a.label.compareTo(b.label);
      });

      if (voices.isNotEmpty) {
        _fTtsVoices = [voices.first];
        _activeFTtsVoice = voices.first;
      }
      _fTtsInitialized = true;
      debugPrint('=== flutter_tts: using voice ${_activeFTtsVoice?.label} ===');
    } catch (e) {
      debugPrint('flutter_tts init error: $e');
    }
  }

  String _friendlyVoiceName(String name, String locale) {
    var label = name
        .replaceAll(
            RegExp(r'en[-_][a-z]{2}[-_]?x[-_]?', caseSensitive: false), '')
        .replaceAll(RegExp(r'[-_#]'), ' ')
        .replaceAll(RegExp(r'\s+local\s*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+network\s*$', caseSensitive: false), '')
        .trim();
    if (label.isEmpty) label = name;
    return label.split(' ').map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');
  }

  // ── Engine switching ──────────────────────────────────────────
  // FIX 3: setEngine calls stopLoop() which now fires _activeOnFinished(false),
  // so the controller resets isPlaying correctly before we switch engine.
  Future<void> setEngine(TtsEngine engine) async {
    if (_engine == engine) return;
    await stopLoop(); // fires _activeOnFinished(false) if a loop is running
    _engine = engine;
  }

  // ── Piper voice switching ─────────────────────────────────────
  // FIX 2 (voice switch): stopLoop() fires _activeOnFinished(false) so the
  // controller's isPlaying is reset. The screen then restarts from the saved
  // sentence index via readFromSentence() after this future resolves.
  Future<void> switchVoice(VoiceModel voice) async {
    if (!_initialized) await init();
    await stopLoop(); // resets controller state via _activeOnFinished
    _activeVoice = voice;
    final modelPath = '$_modelDir/${voice.assetOnnx.split('/').last}';
    await _isolate.spawn(modelPath, _tokensPath, _espeakDir);
    debugPrint('=== PiperTtsService: switched to ${voice.label} ===');
  }

  // ── Flutter TTS voice switching ───────────────────────────────
  Future<void> switchFlutterTtsVoice(FlutterTtsVoice voice) async {
    _activeFTtsVoice = voice;
    try {
      await _fTts.setVoice(voice.raw);
      await _fTts.setLanguage(voice.locale);
    } catch (e) {
      debugPrint('flutter_tts setVoice error: $e');
    }
  }

  // ── Apply flutter_tts speed immediately ──────────────────────
  Future<void> applyFlutterTtsSpeed(double speed) async {
    if (!_fTtsInitialized) return;
    final rate = ((speed - 0.5) / 1.5).clamp(0.0, 1.0);
    try {
      await _fTts.setSpeechRate(rate);
    } catch (e) {
      debugPrint('flutter_tts setSpeechRate error: $e');
    }
  }

  // ── Apply flutter_tts pitch immediately ──────────────────────
  Future<void> applyFlutterTtsPitch(double pitch) async {
    if (!_fTtsInitialized) return;
    try {
      await _fTts.setPitch(pitch.clamp(0.5, 2.0));
    } catch (e) {
      debugPrint('flutter_tts setPitch error: $e');
    }
  }

  void setPitch(double pitch) => _currentPitch = pitch.clamp(0.5, 2.0);

  // ═══════════════════════════════════════════════════════════════
  // LOOP API  (called by AnalyzeController)
  // ═══════════════════════════════════════════════════════════════

  // FIX 1: Accept a speedGetter closure instead of a fixed double so that
  // speed changes made via setSpeed() take effect on the very next sentence
  // without restarting the loop.
  Future<void> startLoop({
    required List<String> sentences,
    required int startIndex,
    required double Function() speedGetter, // ← was: double speed
    required void Function(int index) onSentenceChanged,
    required void Function(bool completed) onFinished,
  }) async {
    if (!_initialized) await init();

    // Cancel any running loop and fire its onFinished(false) first
    _loopGen++;
    final gen = _loopGen;
    _loopRunning = true;

    // Save callback so stopLoop() can always fire it
    _activeOnFinished = onFinished;

    if (_engine == TtsEngine.flutterTts) {
      await _loopFlutterTts(
        sentences: sentences,
        startIndex: startIndex,
        speedGetter: speedGetter,
        gen: gen,
        onSentenceChanged: onSentenceChanged,
        onFinished: onFinished,
      );
    } else {
      await _loopPiper(
        sentences: sentences,
        startIndex: startIndex,
        speedGetter: speedGetter,
        gen: gen,
        onSentenceChanged: onSentenceChanged,
        onFinished: onFinished,
      );
    }
  }

  // FIX 3: stopLoop() now always fires _activeOnFinished(false) so the
  // controller's isPlaying is always reset, regardless of how the loop dies.
  Future<void> stopLoop() async {
    _loopGen++; // invalidates any running loop iteration
    _loopRunning = false;
    _isolate.cancelAll();
    await _playerA.stop();
    await _playerB.stop();
    try {
      await _fTts.stop();
    } catch (_) {}

    // Always notify the controller that the loop has ended
    final cb = _activeOnFinished;
    _activeOnFinished = null;
    cb?.call(false); // false = not naturally completed, was stopped
  }

  bool get isLoopRunning => _loopRunning;

  // ── Piper ping-pong loop ──────────────────────────────────────
  // FIX 1: Uses speedGetter() per sentence so live speed changes are applied.
  Future<void> _loopPiper({
    required List<String> sentences,
    required int startIndex,
    required double Function() speedGetter, // ← closure, always fresh
    required int gen,
    required void Function(int) onSentenceChanged,
    required void Function(bool) onFinished,
  }) async {
    if (sentences.isEmpty || startIndex >= sentences.length) {
      _loopRunning = false;
      _activeOnFinished = null;
      onFinished(true);
      return;
    }

    _slotA = true;

    // Generate the very first sentence up front
    Uint8List? currentBytes =
        await _isolate.generate(sentences[startIndex], speedGetter());

    if (_loopGen != gen) {
      // Loop was cancelled while we were generating — onFinished already fired
      // by stopLoop(), so just return.
      _loopRunning = false;
      return;
    }

    for (int i = startIndex; i < sentences.length; i++) {
      if (_loopGen != gen) break;

      onSentenceChanged(i);

      final file = _currentFile;
      if (file == null || currentBytes == null || currentBytes.isEmpty) {
        _slotA = !_slotA;
        if (i + 1 < sentences.length) {
          // FIX 1: read speed fresh for each sentence
          currentBytes =
              await _isolate.generate(sentences[i + 1], speedGetter());
        }
        continue;
      }

      await file.writeAsBytes(currentBytes, flush: true);

      // Kick off generation of the NEXT sentence in parallel
      // FIX 1: use speedGetter() so any mid-loop speed change is picked up
      Future<Uint8List?>? nextFuture;
      if (i + 1 < sentences.length) {
        nextFuture = _isolate.generate(sentences[i + 1], speedGetter());
      }

      // Play current sentence
      final player = _currentPlayer;
      await player.stop();
      try {
        await player.setFilePath(file.path);
      } catch (e) {
        debugPrint('Piper setFilePath error: $e');
        _slotA = !_slotA;
        if (nextFuture != null) currentBytes = await nextFuture;
        continue;
      }

      await player.play();

      // Wait for playback to finish or loop to be cancelled
      try {
        await player.processingStateStream
            .firstWhere((s) =>
                s == ProcessingState.completed ||
                s == ProcessingState.idle)
            .timeout(const Duration(seconds: 60));
      } catch (_) {}

      if (_loopGen != gen) break;

      currentBytes = nextFuture != null ? await nextFuture : null;
      _slotA = !_slotA;
    }

    // Only fire onFinished if this loop generation is still the active one.
    // If _loopGen != gen it means stopLoop() already fired the callback.
    if (_loopGen == gen) {
      _loopRunning = false;
      _activeOnFinished = null;
      onFinished(true); // true = reached the end naturally
    } else {
      _loopRunning = false;
    }
  }

  // ── Flutter TTS loop ──────────────────────────────────────────
  // FIX 1: Uses speedGetter() per sentence so live speed changes apply.
  Future<void> _loopFlutterTts({
    required List<String> sentences,
    required int startIndex,
    required double Function() speedGetter, // ← closure, always fresh
    required int gen,
    required void Function(int) onSentenceChanged,
    required void Function(bool) onFinished,
  }) async {
    if (!_fTtsInitialized) await _initFlutterTts();

    for (int i = startIndex; i < sentences.length; i++) {
      if (_loopGen != gen) break;

      onSentenceChanged(i);

      final completer = Completer<void>();

      // FIX 1: read speed fresh every sentence
      final rate = ((speedGetter() - 0.5) / 1.5).clamp(0.0, 1.0);
      try {
        await _fTts.setSpeechRate(rate);
        await _fTts.setPitch(_currentPitch.clamp(0.5, 2.0));
      } catch (_) {}

      _fTts.setCompletionHandler(
          () { if (!completer.isCompleted) completer.complete(); });
      _fTts.setCancelHandler(
          () { if (!completer.isCompleted) completer.complete(); });
      _fTts.setErrorHandler(
          (msg) { if (!completer.isCompleted) completer.complete(); });

      await _fTts.speak(sentences[i]);
      await completer.future;
    }

    // Same guard as Piper loop: only fire if we're still the active generation
    if (_loopGen == gen) {
      _loopRunning = false;
      _activeOnFinished = null;
      onFinished(true);
    } else {
      _loopRunning = false;
    }
  }

  // ── Legacy single-speak (kept for health check only) ─────────
  Future<void> speak(String text, {double speed = 1.0}) async {
    if (!_initialized) await init();
    if (text.trim().isEmpty) return;
    final bytes = await _isolate.generate(text, speed);
    if (bytes == null || bytes.isEmpty) return;
    await _fileA!.writeAsBytes(bytes, flush: true);
    await _playerA.stop();
    await _playerA.setFilePath(_fileA!.path);
    await _playerA.play();
    try {
      await _playerA.processingStateStream
          .firstWhere((s) =>
              s == ProcessingState.completed || s == ProcessingState.idle)
          .timeout(const Duration(seconds: 60));
    } catch (_) {}
  }

  Future<void> stop() async => stopLoop();

  bool get isPlaying =>
      _playerA.playing || _playerB.playing || _loopRunning;

  void dispose() {
    _playerA.dispose();
    _playerB.dispose();
  }

  Future<String> _copyAsset(String assetPath, String destPath) async {
    final file = File(destPath);
    if (!file.existsSync()) {
      final data = await rootBundle.load(assetPath);
      await file.writeAsBytes(data.buffer.asUint8List());
    }
    return destPath;
  }

  Future<void> _copyAssetFolder(
      String assetFolderPrefix, String destDir) async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final allAssets = manifest.listAssets();
    final folderAssets = allAssets
        .where((key) => key.startsWith(assetFolderPrefix))
        .toList();

    for (final assetKey in folderAssets) {
      final relativePath = assetKey.substring(assetFolderPrefix.length);
      final destFilePath = '$destDir/$relativePath';
      final destFileDir = Directory(
        destFilePath.substring(0, destFilePath.lastIndexOf('/')),
      );
      if (!await destFileDir.exists()) {
        await destFileDir.create(recursive: true);
      }
      final destFile = File(destFilePath);
      if (!await destFile.exists()) {
        final data = await rootBundle.load(assetKey);
        await destFile.writeAsBytes(data.buffer.asUint8List());
      }
    }
  }
}

// ── WAV builder ───────────────────────────────────────────────
Uint8List _samplesToWavBytes(List<double> samples, int sampleRate) {
  final pcm = Int16List(samples.length);
  for (int i = 0; i < samples.length; i++) {
    pcm[i] = (samples[i].clamp(-1.0, 1.0) * 32767).round();
  }
  final byteData = ByteData(44 + pcm.lengthInBytes);
  void writeStr(int offset, String s) {
    for (int i = 0; i < s.length; i++) {
      byteData.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  writeStr(0, 'RIFF');
  byteData.setUint32(4, 36 + pcm.lengthInBytes, Endian.little);
  writeStr(8, 'WAVE');
  writeStr(12, 'fmt ');
  byteData.setUint32(16, 16, Endian.little);
  byteData.setUint16(20, 1, Endian.little);
  byteData.setUint16(22, 1, Endian.little);
  byteData.setUint32(24, sampleRate, Endian.little);
  byteData.setUint32(28, sampleRate * 2, Endian.little);
  byteData.setUint16(32, 2, Endian.little);
  byteData.setUint16(34, 16, Endian.little);
  writeStr(36, 'data');
  byteData.setUint32(40, pcm.lengthInBytes, Endian.little);
  for (int i = 0; i < pcm.length; i++) {
    byteData.setInt16(44 + i * 2, pcm[i], Endian.little);
  }
  return byteData.buffer.asUint8List();
}