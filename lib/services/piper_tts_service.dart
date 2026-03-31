import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

class PiperTtsService {
  final AudioPlayer player = AudioPlayer();

  bool _initialized = false;
  Future<void>? _initFuture;

  // Paths stored after init so the isolate can use them
  late String _modelPath;
  late String _tokensPath;
  late String _espeakDir;

  Future<void> init() async {
    if (_initialized) return;
    if (_initFuture != null) {
      await _initFuture;
      return;
    }
    _initFuture = _doInit();
    await _initFuture;
  }

  Future<void> _doInit() async {
    debugPrint('=== PiperTtsService: init started ===');
    try {
      final dir = await getApplicationDocumentsDirectory();
      final modelDir  = '${dir.path}/tts_model';
      final espeakDir = '$modelDir/espeak-ng-data';

      await Directory(modelDir).create(recursive: true);
      await Directory(espeakDir).create(recursive: true);

      _modelPath  = await _copyAsset(
        'assets/models/converted/en_US-lessac-medium.onnx',
        '$modelDir/en_US-lessac-medium.onnx',
      );
      _tokensPath = await _copyAsset(
        'assets/models/converted/tokens.txt',
        '$modelDir/tokens.txt',
      );

      const espeakFiles = [
        'en_dict',
        'file_list.txt',
        'intonations',
        'phondata',
        'phondata-manifest',
        'phonindex',
        'phontab',
      ];
      for (final f in espeakFiles) {
        await _copyAsset(
          'assets/models/converted/espeak-ng-data/$f',
          '$espeakDir/$f',
        );
      }

      _espeakDir   = espeakDir;
      _initialized = true;
      debugPrint('=== PiperTtsService: files ready ===');
    } catch (e, stack) {
      debugPrint('=== PiperTtsService: init FAILED: $e ===');
      debugPrint('$stack');
    }
  }

  Future<void> speak(String text) async {
    if (!_initialized) await init();
    if (!_initialized) {
      debugPrint('PiperTtsService: not initialized — cannot speak');
      return;
    }
    if (text.trim().isEmpty) return;

    try {
      debugPrint('PiperTtsService: generating audio in isolate...');

      // Run sherpa entirely in a separate isolate to avoid mutex crash
      final wavBytes = await Isolate.run(() => _generateWav(
        modelPath:  _modelPath,
        tokensPath: _tokensPath,
        espeakDir:  _espeakDir,
        text:       text,
      ));

      if (wavBytes == null) {
        debugPrint('PiperTtsService: isolate returned null');
        return;
      }

      final tmpDir  = await getTemporaryDirectory();
      final wavFile = File('${tmpDir.path}/piper_out.wav');
      await wavFile.writeAsBytes(wavBytes);

      await player.setFilePath(wavFile.path);
      await player.play();
      debugPrint('PiperTtsService: playback started');
    } catch (e, stack) {
      debugPrint('PiperTtsService: speak FAILED: $e');
      debugPrint('$stack');
    }
  }

  Future<void> stop() async {
    await player.stop();
  }

  void dispose() {
    player.dispose();
    _initialized = false;
    _initFuture  = null;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<String> _copyAsset(String assetPath, String destPath) async {
    final file = File(destPath);
    if (!file.existsSync()) {
      debugPrint('PiperTtsService: copying $assetPath...');
      final data = await rootBundle.load(assetPath);
      await file.writeAsBytes(data.buffer.asUint8List());
      debugPrint('PiperTtsService: done (${data.lengthInBytes} bytes)');
    }
    return destPath;
  }
}

// ── Top-level function (required for Isolate.run) ─────────────────────────────
// Must be top-level, not a method, so the isolate can call it.
Uint8List? _generateWav({
  required String modelPath,
  required String tokensPath,
  required String espeakDir,
  required String text,
}) {
  try {
    // initBindings must be called inside the isolate too
    sherpa.initBindings();

    final config = sherpa.OfflineTtsConfig(
      model: sherpa.OfflineTtsModelConfig(
        vits: sherpa.OfflineTtsVitsModelConfig(
          model:       modelPath,
          tokens:      tokensPath,
          dataDir:     espeakDir,
          noiseScale:  0.667,
          noiseScaleW: 0.8,
          lengthScale: 1.0,
        ),
        numThreads: 2,
        debug:      false,
        provider:   'cpu',
      ),
      ruleFsts: '',
    );

    final tts   = sherpa.OfflineTts(config);
    final audio = tts.generate(text: text, sid: 0, speed: 1.0);
    tts.free();

    debugPrint('Isolate: generated ${audio.samples.length} samples at ${audio.sampleRate}Hz');
    return _samplesToWavBytes(audio.samples, audio.sampleRate);
  } catch (e) {
    debugPrint('Isolate error: $e');
    return null;
  }
}

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
  byteData.setUint32(4,  36 + pcm.lengthInBytes, Endian.little);
  writeStr(8, 'WAVE');
  writeStr(12, 'fmt ');
  byteData.setUint32(16, 16, Endian.little);
  byteData.setUint16(20, 1,  Endian.little);
  byteData.setUint16(22, 1,  Endian.little);
  byteData.setUint32(24, sampleRate,     Endian.little);
  byteData.setUint32(28, sampleRate * 2, Endian.little);
  byteData.setUint16(32, 2,  Endian.little);
  byteData.setUint16(34, 16, Endian.little);
  writeStr(36, 'data');
  byteData.setUint32(40, pcm.lengthInBytes, Endian.little);
  for (int i = 0; i < pcm.length; i++) {
    byteData.setInt16(44 + i * 2, pcm[i], Endian.little);
  }

  return byteData.buffer.asUint8List();
}