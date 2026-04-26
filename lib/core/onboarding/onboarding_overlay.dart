import 'package:flutter/material.dart';
import 'onboarding_controller.dart';
import '../../services/piper_tts_service.dart';

class OnboardingOverlay extends StatefulWidget {
  final OnboardingController controller;
  final Widget child;

  const OnboardingOverlay({
    super.key,
    required this.controller,
    required this.child,
  });

  @override
  State<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<OnboardingOverlay> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
  }

  void _rebuild() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;

    if (!ctrl.active) return widget.child;

    // ── Loading screen while replay switches voice ────────────
    if (ctrl.isReplaying && ctrl.stepIndex == 0 && !ctrl.isSpeaking) {
      return Stack(
        children: [
          widget.child,
          Container(
            color: const Color(0xFF1A1A2E),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF1D9E75)),
                  SizedBox(height: 20),
                  Text(
                    'Starting tour…',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Stack(
      children: [
        widget.child,
        _OnboardingFullScreen(controller: widget.controller),
      ],
    );
  }
}

// ── Full-screen onboarding card ───────────────────────────────
class _OnboardingFullScreen extends StatefulWidget {
  final OnboardingController controller;
  const _OnboardingFullScreen({required this.controller});

  @override
  State<_OnboardingFullScreen> createState() =>
      _OnboardingFullScreenState();
}

class _OnboardingFullScreenState extends State<_OnboardingFullScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _anim;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  int _lastIndex = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut)
        .drive(Tween(begin: 0.0, end: 1.0));
    _slide = CurvedAnimation(parent: _anim, curve: Curves.easeOut)
        .drive(Tween(
            begin: const Offset(0.06, 0), end: Offset.zero));
    widget.controller.addListener(_onStepChanged);
    _lastIndex = widget.controller.stepIndex;
    _anim.forward();
  }

  // ── App lifecycle ─────────────────────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      PiperTtsService().resetLoopState();
      widget.controller.resetSpeakingState();
    } else if (state == AppLifecycleState.resumed) {
      if (widget.controller.active) {
        widget.controller.resumeSpeaking();
      }
    }
  }

  void _onStepChanged() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final idx = widget.controller.stepIndex;
      if (idx != _lastIndex) {
        _lastIndex = idx;
        _anim.forward(from: 0);
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_onStepChanged);
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final step = ctrl.currentStep;

    return DefaultTextStyle(
      style: const TextStyle(
        decoration: TextDecoration.none,
        color: Colors.white,
        fontFamily: 'Arial',
      ),
      child: GestureDetector(
        onTap: ctrl.isSkipping ? null : ctrl.fastForward,
        child: Container(
          color: const Color(0xFF1A1A2E),
          child: SafeArea(
            child: Column(
              children: [
                _TopBar(controller: ctrl),
                Expanded(
                  child: FadeTransition(
                    opacity: _fade,
                    child: SlideTransition(
                      position: _slide,
                      child: _CardContent(step: step),
                    ),
                  ),
                ),
                _BottomArea(controller: ctrl),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final OnboardingController controller;
  const _TopBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    final ctrl = controller;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: List.generate(ctrl.totalSteps, (i) {
              final isActive = i == ctrl.stepIndex;
              final isPast = i < ctrl.stepIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(right: 6),
                width: isActive ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.white
                      : isPast
                          ? Colors.white.withOpacity(0.55)
                          : Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          if (!ctrl.isSkipping)
            GestureDetector(
              onTap: ctrl.skip,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 9),
              child: Row(
                children: const [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Finishing…',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Main card content ─────────────────────────────────────────
class _CardContent extends StatelessWidget {
  final OnboardingStep step;
  const _CardContent({required this.step});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              color: step.accentColor.withOpacity(0.18),
              shape: BoxShape.circle,
              border: Border.all(
                  color: step.accentColor.withOpacity(0.5), width: 2.5),
            ),
            child: Icon(step.icon, size: 60, color: step.accentColor),
          ),
          const SizedBox(height: 40),
          Text(
            step.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              height: 1.2,
              letterSpacing: -0.3,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            step.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontSize: 18,
              height: 1.55,
              fontWeight: FontWeight.w400,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom area ───────────────────────────────────────────────
class _BottomArea extends StatelessWidget {
  final OnboardingController controller;
  const _BottomArea({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: controller.isSpeaking
          ? const _SpeakingBadge(key: ValueKey('speaking'))
          : const _TapHint(key: ValueKey('tap')),
    );
  }
}

// ── Amy speaking badge ────────────────────────────────────────
class _SpeakingBadge extends StatefulWidget {
  const _SpeakingBadge({super.key});

  @override
  State<_SpeakingBadge> createState() => _SpeakingBadgeState();
}

class _SpeakingBadgeState extends State<_SpeakingBadge>
    with TickerProviderStateMixin {
  late final List<AnimationController> _bars;
  late final List<Animation<double>> _heights;

  static const _minH = 4.0;
  static const _maxH = 24.0;
  static const List<int> _durations = [310, 390, 260, 430, 350];

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
      return Tween<double>(begin: _minH, end: _maxH).animate(
        CurvedAnimation(parent: _bars[i], curve: Curves.easeInOut),
      );
    });
  }

  @override
  void dispose() {
    for (final c in _bars) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.record_voice_over,
              color: Color(0xFF1D9E75), size: 18),
          const SizedBox(width: 10),
          const Text(
            'Amy is speaking…',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            height: 26,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(5, (i) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: AnimatedBuilder(
                    animation: _heights[i],
                    builder: (_, __) => Container(
                      width: 3.5,
                      height: _heights[i].value,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D9E75),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tap hint ──────────────────────────────────────────────────
class _TapHint extends StatefulWidget {
  const _TapHint({super.key});

  @override
  State<_TapHint> createState() => _TapHintState();
}

class _TapHintState extends State<_TapHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: Colors.white30),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text(
              'Tap anywhere to continue',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}