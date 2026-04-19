import 'package:flutter/material.dart';
import '../features/camera/camera_screen.dart';
import '../features/upload/upload_screen.dart';
import '../core/onboarding/onboarding_controller.dart';

class HomeScreen extends StatelessWidget {
  final OnboardingController? onboardingController;

  const HomeScreen({super.key, this.onboardingController});

  void _openHelp(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _HelpSheet(
        onboardingController: onboardingController,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final btnWidth = (size.width * 0.82).clamp(200.0, 320.0);
    final btnHeight = (size.height * 0.17).clamp(100.0, 150.0);
    final ctrl = onboardingController;

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
            onPressed: () => _openHelp(context),
          ),
        ],
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
                  onPressed: ctrl?.active == true
                      ? null
                      : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const CameraScreen()),
                          ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF38616A),
                    elevation: 15,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
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
                  onPressed: ctrl?.active == true
                      ? null
                      : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const UploadScreen()),
                          ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF38616A),
                    elevation: 15,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
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

// ── Help bottom sheet ─────────────────────────────────────────
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
              final ctrl = onboardingController;
              if (ctrl == null) return;
              // requestReplay() on the controller which lives in
              // MainNavScreen — always mounted, never dies with the sheet
              ctrl.requestReplay();
              Navigator.of(context).pop();
            },
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor
                      .withOpacity(isDisabled ? 0.06 : 0.12),
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
}