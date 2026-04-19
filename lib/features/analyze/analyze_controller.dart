import '../../services/text_extractor_services.dart';
import '../../services/piper_tts_service.dart';

class AnalyzeController {
  final PiperTtsService _tts = PiperTtsService();

  String extractedText = '';
  List<String> paragraphs = [];
  List<List<TextRun>> richParagraphs = [];
  List<String> sentences = [];

  int currentSentenceIndex = 0;
  bool isPlaying = false;
  bool _disposed = false;

  static const double defaultSpeed = 1.0;
  static const double defaultPitch = 1.0;
  static const double minSpeed     = 0.5;
  static const double maxSpeed     = 2.0;
  static const double minPitch     = 0.5;
  static const double maxPitch     = 1.5;

  double speed = defaultSpeed;
  double pitch = defaultPitch;

  List<String> _readSentences = [];
  int _readIndex = 0;
  bool _isReadMode = false;

  // ── Load file ─────────────────────────────────────────────────
  Future<void> loadFile(String path, {String? overrideText}) async {
    await _stopPlayback();

    extractedText        = '';
    paragraphs           = [];
    richParagraphs       = [];
    sentences            = [];
    currentSentenceIndex = 0;
    _isReadMode          = false;
    _readSentences       = [];
    _readIndex           = 0;

    if (overrideText != null && overrideText.isNotEmpty) {
      extractedText  = overrideText;
      paragraphs     = TextExtractorService.toParagraphs(extractedText);
      richParagraphs = paragraphs.map((p) => [TextRun(p)]).toList();
    } else {
      extractedText  = await TextExtractorService.extractText(path);
      paragraphs     = TextExtractorService.toParagraphs(extractedText);
      richParagraphs = await TextExtractorService.extractParagraphRuns(path);
      if (richParagraphs.isEmpty) {
        richParagraphs = paragraphs.map((p) => [TextRun(p)]).toList();
      }
    }

    sentences = paragraphs
        .expand((p) => TextExtractorService.toSentences(p))
        .toList();

    _tts.init();
  }

  // ── Internal stop ─────────────────────────────────────────────
  // NOTE: _stopPlayback() calls _tts.stopLoop() which will fire
  // _activeOnFinished(false) in the service. That callback points to
  // whichever onFinished was passed to the last startLoop() call.
  // We do NOT touch isPlaying here — the onFinished callback does it,
  // which keeps state management in one place.
  Future<void> _stopPlayback() async {
    isPlaying = false;
    await _tts.stopLoop();
  }

  // ── Play / Pause ──────────────────────────────────────────────
  Future<void> playPause(Function updateUI) async {
    if (_disposed) return;

    if (isPlaying) {
      await _stopPlayback();
      updateUI();
      return;
    }

    isPlaying = true;
    updateUI();

    if (_isReadMode) {
      _startReadLoop(updateUI);
    } else {
      _startNormalLoop(updateUI);
    }
  }

  // ── Normal loop — delegates to TTS service ────────────────────
  // FIX 1: Pass () => speed (a closure) instead of speed (a value) so that
  // any mid-loop call to setSpeed() is picked up on the very next sentence.
  void _startNormalLoop(Function updateUI) {
    if (_disposed) return;

    _tts.startLoop(
      sentences: sentences,
      startIndex: currentSentenceIndex,
      speedGetter: () => speed, // ← FIX 1: live closure
      onSentenceChanged: (index) {
        if (_disposed) return;
        currentSentenceIndex = index;
        updateUI();
      },
      onFinished: (completed) {
        if (_disposed) return;
        isPlaying = false;
        if (completed) currentSentenceIndex = 0;
        updateUI();
      },
    );
  }

  // ── Read-selection loop — delegates to TTS service ────────────
  // FIX 1: Same speedGetter closure pattern.
  void _startReadLoop(Function updateUI) {
    if (_disposed) return;

    _tts.startLoop(
      sentences: _readSentences,
      startIndex: _readIndex,
      speedGetter: () => speed, // ← FIX 1: live closure
      onSentenceChanged: (index) {
        if (_disposed) return;
        _readIndex = index;
        updateUI();
      },
      onFinished: (completed) {
        if (_disposed) return;
        isPlaying      = false;
        _isReadMode    = false;
        _readSentences = [];
        _readIndex     = 0;
        updateUI();
      },
    );
  }

  // ── Stop ──────────────────────────────────────────────────────
  Future<void> stop(Function updateUI) async {
    if (_disposed) return;
    await _stopPlayback();
    _isReadMode          = false;
    _readSentences       = [];
    _readIndex           = 0;
    currentSentenceIndex = 0;
    updateUI();
  }

  // ── Read from a specific sentence index ───────────────────────
  Future<void> readFromSentence(int index, Function updateUI) async {
    if (_disposed) return;
    await _stopPlayback();
    _isReadMode          = false;
    currentSentenceIndex = index;
    isPlaying            = true;
    updateUI();
    _startNormalLoop(updateUI);
  }

  // ── Read a selection of text ──────────────────────────────────
  // FIX 1: Uses speedGetter closure so speed changes apply mid-selection too.
  Future<void> readText(
    String text,
    Function onDone, {
    void Function(int index)? onSentenceChanged,
  }) async {
    if (_disposed || text.trim().isEmpty) return;

    await _stopPlayback();

    final raw = text
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    _readSentences = raw.isEmpty ? [text.trim()] : raw;
    _readIndex     = 0;
    _isReadMode    = true;
    isPlaying      = true;

    onSentenceChanged?.call(0);
    onDone();

    _tts.startLoop(
      sentences: _readSentences,
      startIndex: 0,
      speedGetter: () => speed, // ← FIX 1: live closure
      onSentenceChanged: (index) {
        if (_disposed) return;
        _readIndex = index;
        onSentenceChanged?.call(index);
        onDone();
      },
      onFinished: (_) {
        if (_disposed) return;
        isPlaying      = false;
        _isReadMode    = false;
        _readSentences = [];
        _readIndex     = 0;
        onDone();
      },
    );
  }

  bool get isReadMode            => _isReadMode;
  List<String> get readSentences => List.unmodifiable(_readSentences);
  int get readSentenceIndex      => _readIndex;

  // ── Speed / Pitch ─────────────────────────────────────────────
  // FIX 1: For Piper the speed is now picked up automatically via the closure
  // on the next sentence — no restart needed.
  // For flutter_tts we still call applyFlutterTtsSpeed() for the currently
  // speaking sentence (flutter_tts supports live rate change).
  Future<void> setSpeed(double value) async {
    speed = value;
    if (_tts.engine == TtsEngine.flutterTts) {
      await _tts.applyFlutterTtsSpeed(value);
    }
    // Piper: speedGetter() closure picks up the new value on the next
    // generate() call automatically — no extra work needed here.
  }

  Future<void> setPitch(double value) async {
    pitch = value;
    _tts.setPitch(value);
    if (_tts.engine == TtsEngine.flutterTts) {
      await _tts.applyFlutterTtsPitch(value);
    }
  }

  void dispose() {
    _disposed = true;
    _tts.stopLoop();
  }
}