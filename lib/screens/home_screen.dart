import 'package:flutter/material.dart';
import '../../services/speech_recognition_service.dart';
import '../../services/voice_command_service.dart';
import '../../core/onboarding/onboarding_controller.dart';
import '../features/camera/camera_screen.dart';
import '../features/upload/upload_screen.dart';

class HomeScreen extends StatefulWidget {
  final OnboardingController? onboardingController;
  const HomeScreen({super.key, this.onboardingController});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isListening = false;
  String _displayText = '';

  @override
  void initState() {
    super.initState();
    _setup();
  }

  void _setup() async {
    await SpeechRecognitionService.instance.initialize();

    // ── Register commands in UPPERCASE ────────────────────────
    VoiceCommandService.instance.registerCommand('CAMERA', _toCamera);
    VoiceCommandService.instance.registerCommand('SCAN', _toCamera);
    VoiceCommandService.instance.registerCommand('ONE', _toCamera);
    VoiceCommandService.instance.registerCommand('PHOTO', _toCamera);
    VoiceCommandService.instance.registerCommand('TAKE', _toCamera);
    VoiceCommandService.instance.registerCommand('CAPTURE', _toCamera);
    VoiceCommandService.instance.registerCommand('DOCUMENT', _toUpload);
    VoiceCommandService.instance.registerCommand('TWO', _toUpload);
    VoiceCommandService.instance.registerCommand('UPLOAD', _toUpload);
    VoiceCommandService.instance.registerCommand('FILE', _toUpload);

    // ── Wire streams ──────────────────────────────────────────

    // ✅ textStream → display only, do NOT process commands here
    // Processing commands on partials caused double-triggering
    SpeechRecognitionService.instance.textStream.listen((text) {
      if (!mounted) return;
      setState(() => _displayText = text);
      // ❌ Removed: VoiceCommandService.instance.processText(text)
    });

    // ✅ commandStream → commands only (fires on complete utterances)
    SpeechRecognitionService.instance.commandStream.listen((text) {
      if (!mounted) return;
      VoiceCommandService.instance.processText(text);
    });

    SpeechRecognitionService.instance.stateStream.listen((isRec) {
      if (!mounted) return;
      setState(() => _isListening = isRec);
    });
  }

  // ── Navigation ────────────────────────────────────────────────
  void _toCamera() {
    SpeechRecognitionService.instance.stopRecording();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CameraScreen()),
    );
  }

  void _toUpload() {
    SpeechRecognitionService.instance.stopRecording();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UploadScreen()),
    );
  }

  // ── Help sheet ────────────────────────────────────────────────
  void _openHelp() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) =>
          _HelpSheet(onboardingController: widget.onboardingController),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final btnWidth = (size.width * 0.82).clamp(200.0, 320.0);
    final btnHeight = (size.height * 0.17).clamp(100.0, 150.0);
    final ctrl = widget.onboardingController;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 153, 181, 187),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 153, 181, 187),
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            Image.asset('assets/12.png', height: 56),
            const SizedBox(width: 10),
            const Text(
              'Readify',
              style: TextStyle(
                color: Color(0xFF38616A),
                fontWeight: FontWeight.bold,
                fontSize: 28,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Color(0xFF38616A)),
            tooltip: 'Help & About',
            onPressed: _openHelp,
          ),
        ],
      ),

      // ── Hold-to-talk FAB ──────────────────────────────────────
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Live recognition text
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _isListening
                    ? (_displayText.isEmpty ? 'Listening…' : _displayText)
                    : 'Hold to speak',
                key: ValueKey(_isListening ? _displayText : 'idle'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _isListening
                      ? const Color(0xFF1D9E75)
                      : const Color(0xFF38616A),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Mic button
            GestureDetector(
              onTapDown: (_) {
                setState(() => _displayText = '');
                SpeechRecognitionService.instance.startRecording();
              },
              onTapUp: (_) =>
                  SpeechRecognitionService.instance.stopRecording(),
              onTapCancel: () =>
                  SpeechRecognitionService.instance.stopRecording(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isListening
                      ? Colors.redAccent
                      : const Color(0xFF38616A),
                  boxShadow: [
                    BoxShadow(
                      color: (_isListening
                              ? Colors.redAccent
                              : const Color(0xFF38616A))
                          .withOpacity(0.4),
                      blurRadius: _isListening ? 20 : 8,
                      spreadRadius: _isListening ? 4 : 0,
                    ),
                  ],
                ),
                child: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Commands hint
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _isListening ? 0.0 : 1.0,
              child: Text(
                '"Camera"  ·  "Document"  ·  "Upload"',
                style:
                    TextStyle(fontSize: 11, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),

      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: btnWidth,
                height: btnHeight,
                child: ElevatedButton(
                  key: ctrl?.cameraKey,
                  onPressed: ctrl?.active == true ? null : _toCamera,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF38616A),
                    elevation: 15,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt, size: 46),
                        SizedBox(width: 14),
                        Text('Camera',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: size.height * 0.035),
              SizedBox(
                width: btnWidth,
                height: btnHeight,
                child: ElevatedButton(
                  key: ctrl?.documentKey,
                  onPressed: ctrl?.active == true ? null : _toUpload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF38616A),
                    elevation: 15,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.upload_file, size: 46),
                        SizedBox(width: 14),
                        Text('Document',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// HELP SHEET
// ═══════════════════════════════════════════════════════════════
class _HelpSheet extends StatelessWidget {
  final OnboardingController? onboardingController;
  const _HelpSheet({this.onboardingController});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, ctrl) => ListView(
        controller: ctrl,
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text('Help & About',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF38616A))),
          const SizedBox(height: 4),
          const Text('Readify v1.0',
              style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 24),
          _HelpTile(
            icon: Icons.auto_stories,
            iconColor: const Color(0xFF1D9E75),
            title: 'Replay Tutorial',
            subtitle: "Walk through Amy's guided tour again",
            onTap: () {
              final c = onboardingController;
              if (c == null) return;
              c.requestReplay();
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(height: 12),
          _HelpTile(
            icon: Icons.mic,
            iconColor: const Color(0xFF38616A),
            title: 'Voice Commands',
            subtitle:
                'Hold the mic and say "Camera", "Document" or "Upload"',
            onTap: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 12),
          _HelpTile(
            icon: Icons.gavel,
            iconColor: const Color(0xFF38616A),
            title: 'Terms & Conditions',
            subtitle: 'Read our terms of service',
            onTap: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (_) => const _TermsSheet(),
              );
            },
          ),
          const SizedBox(height: 12),
          _HelpTile(
            icon: Icons.info_outline,
            iconColor: Colors.blueGrey,
            title: 'About Readify',
            subtitle: 'An offline-first accessibility reader',
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Readify',
                applicationVersion: '1.0.0',
                applicationIcon:
                    Image.asset('assets/12.png', height: 48),
                children: const [
                  Text(
                    'Readify helps visually impaired users and anyone who '
                    'prefers listening to reading. All processing happens '
                    'offline on your device — no internet required.',
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Help tile ─────────────────────────────────────────────────
class _HelpTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _HelpTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;
    return Material(
      color: isDisabled ? Colors.grey.shade100 : Colors.grey.shade50,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(isDisabled ? 0.06 : 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon,
                    color: isDisabled
                        ? iconColor.withOpacity(0.4)
                        : iconColor,
                    size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDisabled
                                ? Colors.grey.shade400
                                : Colors.black87)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              if (!isDisabled)
                const Icon(Icons.chevron_right,
                    color: Colors.grey, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Terms sheet ───────────────────────────────────────────────
class _TermsSheet extends StatelessWidget {
  const _TermsSheet();

  static const _terms = [
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

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: ListView(
          controller: ctrl,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text('Terms & Conditions',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF38616A))),
            const SizedBox(height: 4),
            const Text('Last updated: 2025',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 20),
            ..._terms.map((section) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(section['title']!,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF38616A))),
                      const SizedBox(height: 6),
                      Text(section['body']!,
                          style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                              height: 1.55)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}