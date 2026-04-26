import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/piper_tts_service.dart';

const amyVoice = VoiceModel(
  id: 'amy',
  label: 'Amy',
  accent: 'en-US',
  assetOnnx: 'assets/models/en_US-amy-medium.onnx',
  assetJson: 'assets/models/en_US-amy-medium.onnx.json',
);

Future<bool> shouldShowOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  return !(prefs.getBool('onboarding_done') ?? false);
}

Future<void> markOnboardingDone() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('onboarding_done', true);
}

Future<void> markOnboardingDoneReset() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('onboarding_done', false);
}

class OnboardingStep {
  final String title;
  final String subtitle;
  final String narration;
  final IconData icon;
  final Color accentColor;

  const OnboardingStep({
    required this.title,
    required this.subtitle,
    required this.narration,
    required this.icon,
    this.accentColor = const Color(0xFF1D9E75),
  });
}

const List<OnboardingStep> onboardingSteps = [
  OnboardingStep(
    icon: Icons.record_voice_over,
    title: 'Welcome to Readify',
    subtitle: "I'm Amy — your reading companion.",
    narration:
        'Hi there! Welcome to Readify. '
        "I'm Amy, and I'll be your guide. "
        'Readify turns text from photos and documents into clear spoken audio, '
        'entirely offline on your device. '
        'Tap anywhere on the screen to move to the next step.',
    accentColor: Color(0xFF1D9E75),
  ),
  OnboardingStep(
    icon: Icons.camera_alt,
    title: 'Camera',
    subtitle: 'Photograph any text to read it aloud.',
    narration:
        'The Camera button lets you photograph any text you want to hear. '
        'It works great for books, signs, menus, and handwritten notes. '
        'Readify scans and extracts all the words automatically.',
    accentColor: Color(0xFF2196F3),
  ),
  OnboardingStep(
    icon: Icons.upload_file,
    title: 'Documents',
    subtitle: 'Import PDF, Word, or text files from your device.',
    narration:
        'The Document button lets you import files from your device. '
        'Readify supports PDF, Word documents, plain text, and image files. '
        'Once imported, the text is extracted and ready to listen to.',
    accentColor: Color(0xFF9C27B0),
  ),
  OnboardingStep(
    icon: Icons.history,
    title: 'History',
    subtitle: 'Your recent files are always one tap away.',
    narration:
        'The History tab at the bottom saves all your recently opened files. '
        'Tap any item to jump straight back to it. '
        'You never have to search for a file twice.',
    accentColor: Color(0xFFE65100),
  ),
  OnboardingStep(
    icon: Icons.play_circle_fill,
    title: 'Play & Listen',
    subtitle: 'Each sentence highlights as it is spoken.',
    narration:
        'Inside the reader, tap the Play button to start listening. '
        'Each sentence lights up as it is read, so you can always follow along. '
        'You can pause or stop at any time.',
    accentColor: Color(0xFF1D9E75),
  ),
  OnboardingStep(
    icon: Icons.speed,
    title: 'Reading Speed',
    subtitle: 'Go faster or slower with the speed slider.',
    narration:
        'Use the Speed slider at the bottom of the reader to control the pace. '
        'Slow it down when learning something new, or speed it up for a quick listen. '
        'The setting stays wherever you leave it.',
    accentColor: Color(0xFF2196F3),
  ),
  OnboardingStep(
    icon: Icons.mic,
    title: 'Voice Commands',
    subtitle: 'Control Readify hands-free with your voice.',
    narration:
        'You can control Readify using your voice — no tapping needed. '
        'Say Play to begin listening, and Pause or Stop to pause. '
        'Say Change voice to switch between available voices. '
        'Just tap the microphone icon on the reader screen to activate voice commands.',
    accentColor: Color(0xFFE91E63),
  ),
  OnboardingStep(
    icon: Icons.record_voice_over,
    title: 'Choose a Voice',
    subtitle: "Switch between Lessac, Alan, or me — Amy!",
    narration:
        'Tap the green microphone button inside the reader to change the reading voice. '
        'You can choose between Lessac, Alan, or me, Amy! '
        "You can also use your device's built-in voices. "
        "That's everything — you're all set! Enjoy Readify!",
    accentColor: Color(0xFF9C27B0),
  ),
];

class OnboardingController extends ChangeNotifier {
  final GlobalKey cameraKey = GlobalKey();
  final GlobalKey documentKey = GlobalKey();
  final GlobalKey historyTabKey = GlobalKey();
  final GlobalKey playBtnKey = GlobalKey();
  final GlobalKey speedSliderKey = GlobalKey();
  final GlobalKey voiceFabKey = GlobalKey();

  VoidCallback? onFinished;

  bool _active = false;
  bool _isSpeaking = false;
  bool _isSkipping = false;
  bool _isReplaying = false;
  int _stepIndex = 0;

  bool get active => _active;
  bool get isSpeaking => _isSpeaking;
  bool get isSkipping => _isSkipping;
  bool get isReplaying => _isReplaying;
  int get stepIndex => _stepIndex;
  int get totalSteps => onboardingSteps.length;
  OnboardingStep get currentStep => onboardingSteps[_stepIndex];

  void assignKeys() {}

  // ── Split narration into sentences ────────────────────────────
  List<String> _splitNarration(String narration) {
    return narration
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  // ── Start ─────────────────────────────────────────────────────
  Future<void> start() async {
    _active = true;
    _stepIndex = 0;
    _isSkipping = false;
    _isReplaying = false;
    _safeNotify();
    await _speakCurrent();
  }

  // ── Replay ────────────────────────────────────────────────────
  Future<void> requestReplay() async {
    if (_isReplaying) return;

    _isReplaying = true;
    _safeNotify();

    try {
      final tts = PiperTtsService();
      await tts.init();
      if (tts.activeVoice.id != amyVoice.id) {
        await tts.switchVoice(amyVoice);
      }
    } catch (_) {}

    await start();
  }

  // ── Speak current step using ping-pong loop ───────────────────
  Future<void> _speakCurrent() async {
    if (!_active || _isSkipping) return;
    _isSpeaking = true;
    _safeNotify();

    try {
      final sentences = _splitNarration(currentStep.narration);
      await PiperTtsService().startLoop(
        sentences: sentences,
        startIndex: 0,
        speedGetter: () => 1.0,
        onSentenceChanged: (_) {},
        onFinished: (_) {
          if (_active && !_isSkipping) {
            _isSpeaking = false;
            _safeNotify();
          }
        },
      );
    } catch (_) {
      _isSpeaking = false;
      _safeNotify();
    }
  }

  // ── Fast forward ──────────────────────────────────────────────
  Future<void> fastForward() async {
    if (!_active || _isSkipping) return;
    PiperTtsService().resetLoopState();
    _isSpeaking = false;

    if (_stepIndex >= onboardingSteps.length - 1) {
      await _finish();
    } else {
      _stepIndex++;
      _safeNotify();
      await _speakCurrent();
    }
  }

  // ── Skip ──────────────────────────────────────────────────────
  Future<void> skip() async {
    if (_isSkipping) return;
    _isSkipping = true;
    _safeNotify();
    PiperTtsService().resetLoopState();

    try {
      await PiperTtsService().startLoop(
        sentences: ['Skipping the tour.', 'Enjoy Readify!'],
        startIndex: 0,
        speedGetter: () => 1.0,
        onSentenceChanged: (_) {},
        onFinished: (_) {},
      );
    } catch (_) {}

    await _finish();
  }

  // ── Finish ────────────────────────────────────────────────────
  Future<void> _finish() async {
    PiperTtsService().resetLoopState();
    try {
      await PiperTtsService().switchVoice(availableVoices.first);
    } catch (_) {}
    await markOnboardingDone();
    _active = false;
    _isSpeaking = false;
    _isSkipping = false;
    _isReplaying = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
      onFinished?.call();
    });
  }

  // ── Called when app is backgrounded ──────────────────────────
  void resetSpeakingState() {
    _isSpeaking = false;
    _safeNotify();
  }

  // ── Called when app resumes ───────────────────────────────────
  Future<void> resumeSpeaking() async {
    await _speakCurrent();
  }

  // ── Safe notify ───────────────────────────────────────────────
  void _safeNotify() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    PiperTtsService().resetLoopState();
    super.dispose();
  }
}