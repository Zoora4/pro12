import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'history_screen.dart';
import '../core/onboarding/onboarding_controller.dart';
import '../core/onboarding/onboarding_overlay.dart';

class MainNavScreen extends StatefulWidget {
  final bool startOnboarding;

  const MainNavScreen({
    super.key,
    this.startOnboarding = false,
  });

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _navIndex = 0;
  late final OnboardingController _onboardingCtrl;

  @override
  void initState() {
    super.initState();
    _onboardingCtrl = OnboardingController();

    _onboardingCtrl.onFinished = () {
      if (mounted) setState(() {});
    };

    _onboardingCtrl.addListener(() {
      if (mounted) setState(() {});
    });

    if (widget.startOnboarding) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onboardingCtrl.start();
      });
    }
  }

  @override
  void dispose() {
    _onboardingCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        OnboardingOverlay(
          controller: _onboardingCtrl,
          child: Scaffold(
            body: IndexedStack(
              index: _navIndex,
              children: [
                HomeScreen(onboardingController: _onboardingCtrl),
                const HistoryScreen(),
              ],
            ),
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: _navIndex,
              onTap: _onboardingCtrl.active
                  ? null
                  : (i) => setState(() => _navIndex = i),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.history),
                  label: 'History',
                ),
              ],
            ),
          ),
        ),

        // ── Replay loading overlay ────────────────────────────
        if (_onboardingCtrl.isReplaying && !_onboardingCtrl.active)
          DefaultTextStyle(
            style: const TextStyle(
              decoration: TextDecoration.none,
              color: Colors.white,
              fontFamily: 'Arial',
            ),
            child: Container(
              color: Colors.black.withOpacity(0.52),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 32,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: const Color(0xFF38616A).withOpacity(0.10),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.record_voice_over,
                          color: Color(0xFF38616A),
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Preparing Amy…',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF38616A),
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Loading voice model, please wait',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                          height: 1.4,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: const SizedBox(
                          width: 160,
                          child: LinearProgressIndicator(
                            backgroundColor: Color(0xFFDDE8EA),
                            color: Color(0xFF38616A),
                            minHeight: 4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}