import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/piper_tts_service.dart';
import '../../services/speech_recognition_service.dart';
import '../../services/voice_command_service.dart';
import 'main_nav_screen.dart';

// ── Prefs helpers ─────────────────────────────────────────────
Future<bool> hasAcceptedTerms() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('terms_accepted') ?? false;
}

Future<void> markTermsAccepted() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('terms_accepted', true);
}

// ── Terms content ─────────────────────────────────────────────
const _terms = [
  {
    'title': '1. Acceptance of Terms',
    'body':
        'By downloading and using Readify, you agree to these Terms and Conditions. '
            'If you do not agree, please do not use the application.',
  },
  {
    'title': '2. Use of the Application',
    'body':
        'Readify is provided for personal, non-commercial use. You may not modify, '
            'distribute, or reverse-engineer any part of the application. '
            'You are responsible for the content you import into the app.',
  },
  {
    'title': '3. Privacy & Data',
    'body':
        'Readify operates entirely offline. No personal data, files, or usage information '
            'is collected, transmitted, or stored outside of your device. '
            'Your files remain private and are only accessible to you.',
  },
  {
    'title': '4. Accessibility',
    'body':
        'Readify is designed as an accessibility tool. We are committed to maintaining '
            'features that support users with visual impairments and reading difficulties.',
  },
  {
    'title': '5. Intellectual Property',
    'body':
        'All application code, assets, and voice models included with Readify are '
            'subject to their respective licenses. Piper TTS voices are used under '
            'open-source license terms.',
  },
  {
    'title': '6. Disclaimer',
    'body':
        'Readify is provided "as is" without warranties of any kind. We are not liable '
            'for any damages arising from the use or inability to use the application.',
  },
  {
    'title': '7. Changes to Terms',
    'body':
        'We may update these terms from time to time. Continued use of the app after '
            'changes constitutes acceptance of the new terms.',
  },
];

// ── One sentence per section for startLoop() ─────────────────
List<String> get _termsSentences => [
  for (final t in _terms) '${t['title']}. ${t['body']}',
];

// ─────────────────────────────────────────────────────────────
// Terms Screen
// ─────────────────────────────────────────────────────────────
class TermsScreen extends StatefulWidget {
  final bool startOnboarding;
  const TermsScreen({super.key, this.startOnboarding = false});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  final ScrollController _scrollCtrl = ScrollController();

  final List<GlobalKey> _sectionKeys =
      List.generate(_terms.length, (_) => GlobalKey());

  bool _hasScrolledToBottom = false;
  bool _checkboxChecked     = false;

  // ── TTS ───────────────────────────────────────────────────
  final _tts            = PiperTtsService();
  bool  _ttsPlaying     = false;
  bool  _ttsReady       = false;
  int   _highlightIndex = -1;

  // ── Voice command ─────────────────────────────────────────
  bool   _micListening = false;
  String _micDisplay   = '';
  StreamSubscription<String>? _cmdSub;
  StreamSubscription<String>? _textSub;
  StreamSubscription<bool>?   _stateSub;

  static const Color _accent = Color(0xFF38616A);
  static const Color _bg     = Color(0xFFE8EDEF);

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _initTts();
    _initVoice();
  }

  // ── TTS init ──────────────────────────────────────────────
  Future<void> _initTts() async {
    if (mounted) setState(() => _ttsReady = true);
  }

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.animateTo(
      _scrollCtrl.position.maxScrollExtent,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
    );
  }

  void _scrollToSection(int index) {
    if (index < 0 || index >= _sectionKeys.length) return;
    final ctx = _sectionKeys[index].currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      alignment: 0.1,
    );
  }

  Future<void> _toggleTts() async {
    if (_ttsPlaying) {
      await _tts.stop();
    } else {
      if (mounted) setState(() => _ttsPlaying = true);
      await _tts.init();
      _tts.startLoop(
        sentences: _termsSentences,
        startIndex: 0,
        speedGetter: () => 1.0,
        onSentenceChanged: (i) {
          if (!mounted) return;
          setState(() => _highlightIndex = i);
          _scrollToSection(i);
        },
        onFinished: (completed) {
          if (!mounted) return;
          setState(() {
            _ttsPlaying     = false;
            _highlightIndex = -1;
          });
          if (completed && !_hasScrolledToBottom) _scrollToBottom();
        },
      );
    }
  }

  // ── Voice command init ────────────────────────────────────
  Future<void> _initVoice() async {
    await SpeechRecognitionService.instance.initialize();

    VoiceCommandService.instance.registerCommand('ACCEPT',      _voiceAccept);
    VoiceCommandService.instance.registerCommand('AGREE',       _voiceAccept);
    VoiceCommandService.instance.registerCommand('I AGREE',     _voiceAccept);
    VoiceCommandService.instance.registerCommand('CONFIRM',     _voiceAccept);
    VoiceCommandService.instance.registerCommand('DECLINE',     _voiceDecline);
    VoiceCommandService.instance.registerCommand('REJECT',      _voiceDecline);
    VoiceCommandService.instance.registerCommand('READ',        _voiceRead);
    VoiceCommandService.instance.registerCommand('READ TERMS',  _voiceRead);
    VoiceCommandService.instance.registerCommand('RTERMS',      _voiceRead);
    VoiceCommandService.instance.registerCommand('PLAY',        _voiceRead);
    VoiceCommandService.instance.registerCommand('STOP',        _voiceStop);
    VoiceCommandService.instance.registerCommand('PAUSE',       _voiceStop);
    VoiceCommandService.instance.registerCommand('SCROLL DOWN', _voiceScrollDown);
    VoiceCommandService.instance.registerCommand('DOWN',        _voiceScrollDown);
    VoiceCommandService.instance.registerCommand('SCROLL UP',   _voiceScrollUp);
    VoiceCommandService.instance.registerCommand('UP',          _voiceScrollUp);

    _textSub = SpeechRecognitionService.instance.textStream.listen((t) {
      if (!mounted) return;
      setState(() => _micDisplay = t);
    });

    // ── KEY CHANGE: auto-stop mic after command is detected ──
    _cmdSub = SpeechRecognitionService.instance.commandStream.listen((t) {
      if (!mounted) return;
      VoiceCommandService.instance.processText(t);
      SpeechRecognitionService.instance.stopRecording();
    });

    _stateSub = SpeechRecognitionService.instance.stateStream.listen((v) {
      if (!mounted) return;
      setState(() => _micListening = v);
    });
  }

  // ── Voice actions ─────────────────────────────────────────
  void _voiceAccept() {
    if (!_hasScrolledToBottom) {
      _scrollToBottom();
      return;
    }
    setState(() => _checkboxChecked = true);
    Future.delayed(const Duration(milliseconds: 300), _onAccept);
  }

  void _voiceDecline() => _onDecline();

  void _voiceRead() => _toggleTts();

  void _voiceStop() async {
    await _tts.stop();
  }

  void _voiceScrollDown() {
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.animateTo(
      (_scrollCtrl.offset + 400)
          .clamp(0.0, _scrollCtrl.position.maxScrollExtent),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  void _voiceScrollUp() {
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.animateTo(
      (_scrollCtrl.offset - 400)
          .clamp(0.0, _scrollCtrl.position.maxScrollExtent),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  // ── Scroll listener ───────────────────────────────────────
  void _onScroll() {
    if (_hasScrolledToBottom) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 40) {
      setState(() => _hasScrolledToBottom = true);
    }
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _tts.stop();
    _tts.resetLoopState();
    _cmdSub?.cancel();
    _textSub?.cancel();
    _stateSub?.cancel();
    SpeechRecognitionService.instance.stopRecording();
    VoiceCommandService.instance.unregisterAll();
    super.dispose();
  }

  Future<void> _onAccept() async {
    await _tts.stop();
    _tts.resetLoopState();

    await SpeechRecognitionService.instance.stopRecording();

    VoiceCommandService.instance.unregisterAll();

    await markTermsAccepted();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            MainNavScreen(startOnboarding: widget.startOnboarding),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _onDecline() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _DeclineDialog(),
    );
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final canAccept = _hasScrolledToBottom && _checkboxChecked;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: _bg,
        floatingActionButton: _buildFabs(),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Stack(
                  children: [
                    ListView.separated(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
                      itemCount: _terms.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 20),
                      itemBuilder: (_, i) => _TermsSection(
                        key: _sectionKeys[i],
                        title: _terms[i]['title']!,
                        body: _terms[i]['body']!,
                        highlighted: _highlightIndex == i,
                      ),
                    ),
                    if (!_hasScrolledToBottom)
                      Positioned(
                        left: 0, right: 0, bottom: 0,
                        child: IgnorePointer(
                          child: Container(
                            height: 64,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  _bg.withOpacity(0),
                                  _bg.withOpacity(0.95),
                                ],
                              ),
                            ),
                            child: const Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.keyboard_arrow_down,
                                      color: _accent, size: 20),
                                  SizedBox(width: 4),
                                  Text(
                                    'Scroll to read all terms',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _accent,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              _buildFooter(canAccept),
            ],
          ),
        ),
      ),
    );
  }

  // ── FABs ──────────────────────────────────────────────────
  Widget _buildFabs() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 200),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [

          if (_micListening && _micDisplay.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 6, right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _micDisplay,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

          // ── KEY CHANGE: tap to start, auto-stops when command detected ──
          GestureDetector(
            onTap: () {
              if (!_micListening) {
                setState(() => _micDisplay = '');
                SpeechRecognitionService.instance.startRecording();
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _micListening
                        ? Colors.redAccent
                        : const Color(0xFF38616A),
                    boxShadow: [
                      BoxShadow(
                        color: (_micListening
                                ? Colors.redAccent
                                : const Color(0xFF38616A))
                            .withOpacity(0.4),
                        blurRadius: _micListening ? 20 : 8,
                        spreadRadius: _micListening ? 3 : 0,
                      ),
                    ],
                  ),
                  child: Icon(
                    _micListening ? Icons.mic : Icons.mic_none,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _micListening ? 'Listening...' : 'Tap',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _micListening ? Colors.redAccent : _accent,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          GestureDetector(
            onTap: _ttsReady ? _toggleTts : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _ttsPlaying
                        ? const Color(0xFF1D9E75)
                        : Colors.white,
                    border: Border.all(color: _accent, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: _accent.withOpacity(0.25),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Icon(
                    _ttsPlaying
                        ? Icons.pause_rounded
                        : Icons.volume_up_rounded,
                    color: _ttsPlaying ? Colors.white : _accent,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _ttsPlaying ? 'Pause' : 'Read',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _accent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: const BoxDecoration(
        color: _accent,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset('assets/12.png', height: 40),
              const SizedBox(width: 12),
              const Text(
                'Readify',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Terms & Conditions',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Please read and accept the terms before using the app.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.80),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mic, color: Colors.white70, size: 14),
                SizedBox(width: 6),
                Text(
                  'Tap mic · Say "Read terms"  ·  "Accept"',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Footer ────────────────────────────────────────────────
  Widget _buildFooter(bool canAccept) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _hasScrolledToBottom
                ? () => setState(
                    () => _checkboxChecked = !_checkboxChecked)
                : null,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _hasScrolledToBottom ? 1.0 : 0.4,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(top: 1),
                    decoration: BoxDecoration(
                      color: _checkboxChecked ? _accent : Colors.white,
                      border: Border.all(
                        color: _checkboxChecked
                            ? _accent
                            : Colors.grey.shade400,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: _checkboxChecked
                        ? const Icon(Icons.check,
                            color: Colors.white, size: 15)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'I have read and agree to the Terms and Conditions of Readify.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF333333),
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: canAccept ? 1.0 : 0.45,
              child: ElevatedButton(
                onPressed: canAccept ? _onAccept : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _accent,
                  disabledForegroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: canAccept ? 4 : 0,
                ),
                child: const Text(
                  'Accept & Continue',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _onDecline,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: const Text(
                'Decline',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Individual terms section — supports highlight state
// ─────────────────────────────────────────────────────────────
class _TermsSection extends StatelessWidget {
  final String title;
  final String body;
  final bool highlighted;

  const _TermsSection({
    super.key,
    required this.title,
    required this.body,
    this.highlighted = false,
  });

  static const Color _accent      = Color(0xFF38616A);
  static const Color _highlightBg = Color(0xFFE0F2F1);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlighted ? _highlightBg : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlighted ? _accent : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: highlighted
                ? _accent.withOpacity(0.18)
                : Colors.black.withOpacity(0.04),
            blurRadius: highlighted ? 14 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (highlighted)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: _accent,
                  ),
                ),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: highlighted ? _accent : _accent,
                  ),
                ),
              ),
              if (highlighted)
                const Icon(Icons.volume_up_rounded,
                    color: _accent, size: 16),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              fontSize: 13,
              color: highlighted
                  ? const Color(0xFF2C2C2C)
                  : const Color(0xFF444444),
              height: 1.6,
              fontWeight:
                  highlighted ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Decline dialog
// ─────────────────────────────────────────────────────────────
class _DeclineDialog extends StatelessWidget {
  const _DeclineDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              color: Color(0xFFD85A30), size: 26),
          SizedBox(width: 10),
          Text(
            'Are you sure?',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      content: const Text(
        'You must accept the Terms and Conditions to use Readify. '
        'Declining will close the app.',
        style: TextStyle(
            fontSize: 14, height: 1.5, color: Color(0xFF444444)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Review again',
            style: TextStyle(
              color: Color(0xFF38616A),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () => SystemNavigator.pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD85A30),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text(
            'Exit app',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}