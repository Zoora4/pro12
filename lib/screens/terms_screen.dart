import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

// ─────────────────────────────────────────────────────────────
// Terms Screen
// ─────────────────────────────────────────────────────────────
class TermsScreen extends StatefulWidget {
  /// Whether to start the onboarding tour after acceptance.
  final bool startOnboarding;

  const TermsScreen({super.key, this.startOnboarding = false});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  final ScrollController _scrollCtrl = ScrollController();
  bool _hasScrolledToBottom = false;
  bool _checkboxChecked = false;

  static const Color _accent = Color(0xFF38616A);
  static const Color _bg = Color(0xFFE8EDEF);

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

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
    super.dispose();
  }

  Future<void> _onAccept() async {
    await markTermsAccepted();

    if (!mounted) return;

    // ── Navigate using THIS screen's own live context ─────────
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => MainNavScreen(
          startOnboarding: widget.startOnboarding,
        ),
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

  @override
  Widget build(BuildContext context) {
    final canAccept = _hasScrolledToBottom && _checkboxChecked;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Stack(
                  children: [
                    ListView.separated(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                      itemCount: _terms.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 20),
                      itemBuilder: (_, i) => _TermsSection(
                        title: _terms[i]['title']!,
                        body: _terms[i]['body']!,
                      ),
                    ),
                    if (!_hasScrolledToBottom)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
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
        ],
      ),
    );
  }

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
          // ── Checkbox ─────────────────────────────────────────
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
                      color:
                          _checkboxChecked ? _accent : Colors.white,
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

          // ── Accept button ─────────────────────────────────────
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

          // ── Decline button ────────────────────────────────────
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
// Individual terms section
// ─────────────────────────────────────────────────────────────
class _TermsSection extends StatelessWidget {
  final String title;
  final String body;

  const _TermsSection({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _accent,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF444444),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  static const Color _accent = Color(0xFF38616A);
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
            style:
                TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
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