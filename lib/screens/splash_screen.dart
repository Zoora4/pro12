import 'package:flutter/material.dart';
import '../services/piper_tts_service.dart';
import '../core/onboarding/onboarding_controller.dart';
import '../screens/terms_screen.dart';
import 'main_nav_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final List<AnimationController> _bars;
  late final List<Animation<double>> _heights;

  static const List<int> _durations = [400, 320, 280, 320, 400];
  static const List<double> _minH = [0.25, 0.4, 0.55, 0.4, 0.25];

  String _statusText = 'Loading voice model…';

  @override
  void initState() {
    super.initState();

    _bars = List.generate(5, (i) {
      return AnimationController(
        vsync: this,
        duration: Duration(milliseconds: _durations[i]),
      )..repeat(reverse: true);
    });

    _heights = List.generate(5, (i) {
      return Tween<double>(begin: _minH[i], end: 1.0).animate(
        CurvedAnimation(parent: _bars[i], curve: Curves.easeInOut),
      );
    });

    _loadAndProceed();
  }

  Future<void> _loadAndProceed() async {
    final tts = PiperTtsService();

    final results = await Future.wait([
      tts.init().then((_) async {
        if (tts.activeVoice.id != amyVoice.id) {
          if (mounted) setState(() => _statusText = 'Switching to Amy…');
          await tts.switchVoice(amyVoice);
        }
      }),
      hasAcceptedTerms(),
      shouldShowOnboarding(),
    ]);

    if (!mounted) return;

    final termsAccepted  = results[1] as bool;
    final showOnboarding = results[2] as bool;

    setState(() => _statusText = 'Ready!');
    await Future.delayed(const Duration(milliseconds: 250));

    if (!mounted) return;

    if (!termsAccepted) {
      // ── Pass showOnboarding to TermsScreen so it can navigate
      // entirely on its own context after acceptance — no closure
      // capturing SplashScreen's (already-dead) context.
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => TermsScreen(
            startOnboarding: showOnboarding,
          ),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => MainNavScreen(
            startOnboarding: showOnboarding,
          ),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  @override
  void dispose() {
    for (final c in _bars) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: DefaultTextStyle(
        style: const TextStyle(
          decoration: TextDecoration.none,
          color: Colors.white,
          fontFamily: 'Arial',
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFF1D9E75).withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF1D9E75).withOpacity(0.4),
                    width: 2.5,
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Image.asset(
                  'assets/12.png',
                  fit: BoxFit.contain,
                ),
              ),

              const SizedBox(height: 28),

              const Text(
                'Readify',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  decoration: TextDecoration.none,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Preparing your reading companion…',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 15,
                  decoration: TextDecoration.none,
                ),
              ),

              const SizedBox(height: 48),

              SizedBox(
                height: 40,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(5, (i) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: AnimatedBuilder(
                        animation: _heights[i],
                        builder: (_, __) => Container(
                          width: 5,
                          height: 40 * _heights[i].value,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1D9E75),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),

              const SizedBox(height: 24),

              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _statusText,
                  key: ValueKey(_statusText),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.38),
                    fontSize: 13,
                    decoration: TextDecoration.none,
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