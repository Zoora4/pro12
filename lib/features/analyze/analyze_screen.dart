import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../camera/image_region_screen.dart';
import '../../services/piper_tts_service.dart';
import '../../services/speech_recognition_service.dart';
import 'analyze_controller.dart';

// ── Easy-to-tweak position constants ─────────────────────────

const double _kFabBottomOffset = 10.0;
const double _kFabRightOffset  = 16.0;
const double _kFabLeftOffset   = 16.0;

class AnalyzeScreen extends StatefulWidget {
  final String filePath;
  final bool backToHome;
  final String? overrideText;
  final File? sourceImageFile;

  const AnalyzeScreen({
    super.key,
    required this.filePath,
    this.backToHome = false,
    this.overrideText,
    this.sourceImageFile,
  });

  @override
  State<AnalyzeScreen> createState() => _AnalyzeScreenState();
}

class _AnalyzeScreenState extends State<AnalyzeScreen>
    with WidgetsBindingObserver {
  late AnalyzeController controller;
  bool _isExiting        = false;
  bool _loaded           = false;
  bool _isSwitchingVoice = false;

  // ── Text customization defaults ───────────────────────────────
  static const double     _defaultFontSize   = 18;
  static const double     _defaultLineHeight = 2.0;
  static const FontWeight _defaultFontWeight = FontWeight.w400;

  double     _fontSize   = _defaultFontSize;
  double     _lineHeight = _defaultLineHeight;
  FontWeight _fontWeight = _defaultFontWeight;
  bool       _focusMode  = false;

  String _selectedText = '';

  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey>  _sentenceKeys     = [];

  // ── Bottom bar height tracker for FAB positioning ─────────────
  final GlobalKey _bottomBarKey    = GlobalKey();
  double          _bottomBarHeight = 160;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = AnalyzeController();
    _init();
    WidgetsBinding.instance.addPostFrameCallback(_measureBottomBar);
  }

  void _measureBottomBar(_) {
    final rb = _bottomBarKey.currentContext?.findRenderObject() as RenderBox?;
    if (rb != null && mounted) {
      setState(() => _bottomBarHeight = rb.size.height);
    }
  }

  Future<void> _init() async {
    // ── Flush any lingering TTS from onboarding before loading ──
    final tts = PiperTtsService();
    await tts.stop();
    tts.resetLoopState(); // ← Clear cached sentences from previous screens

    await controller.loadFile(
      widget.filePath,
      overrideText: widget.overrideText,
    );
    _sentenceKeys.clear();
    for (int i = 0; i < controller.sentences.length; i++) {
      _sentenceKeys.add(GlobalKey());
    }
    if (mounted) setState(() => _loaded = true);
  }

  String get _ext          => widget.filePath.split('.').last.toLowerCase();
  bool   get _isImg        => ['jpg', 'jpeg', 'png'].contains(_ext);
  bool   get _showReselect => _isImg && widget.sourceImageFile != null;

  void _handleBack() {
    if (_isExiting) return;
    _isExiting = true;
    controller.dispose();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _reselect() async {
    final newText = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        builder: (_) => ImageRegionScreen(
          imageFile: widget.sourceImageFile!,
          backToHome: false,
        ),
      ),
    );
    if (newText != null && mounted) {
      await controller.loadFile(widget.filePath, overrideText: newText);
      setState(() {});
    }
  }

  void _scrollToSentence(int index) {
    if (index >= _sentenceKeys.length) return;
    final ctx = _sentenceKeys[index].currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      alignment: 0.3,
    );
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {});
    if (!controller.isReadMode && controller.isPlaying) {
      _scrollToSentence(controller.currentSentenceIndex);
    }
  }

  Future<void> _resetToDefaults() async {
    await controller.setSpeed(AnalyzeController.defaultSpeed);
    await controller.setPitch(AnalyzeController.defaultPitch);
    setState(() {
      _fontSize   = _defaultFontSize;
      _lineHeight = _defaultLineHeight;
      _fontWeight = _defaultFontWeight;
      _focusMode  = false;
    });
  }

  void _startReadSelection(String text) {
    if (text.isEmpty) return;
    controller.readText(
      text,
      () { if (mounted) setState(() {}); },
      onSentenceChanged: (_) { if (mounted) setState(() {}); },
    );
    setState(() {});
  }

  void _handlePlayPause() {
    // ── Guard: never play until document is fully loaded ────────
    if (!_loaded) return;

    final wasPlaying = controller.isPlaying;
    controller.playPause(_refresh);
    if (!wasPlaying && !controller.isReadMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSentence(controller.currentSentenceIndex);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      controller.stop(() { if (mounted) setState(() {}); });
    }
  }

  // ── Voice selector bottom sheet ───────────────────────────────
  void _openVoiceSelector() {
    final tts = PiperTtsService();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final isPiper = tts.engine == TtsEngine.piper;
          return SafeArea(
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.92,
              builder: (_, scrollCtrl) => Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: ListView(
                  controller: scrollCtrl,
                  children: [
                    _sheetHandle(),
                    const Text('Voice & Engine',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    const Text('Choose your TTS engine and voice',
                        style: TextStyle(fontSize: 14, color: Colors.grey)),
                    const SizedBox(height: 20),
                    _EngineToggle(
                      selected: tts.engine,
                      onChanged: (e) async {
                        await tts.setEngine(e);
                        setSheet(() {});
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 20),
                    Text(
                      isPiper
                          ? 'Piper voices  (offline · high quality)'
                          : 'Device voices  (system TTS)',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                          letterSpacing: 0.4),
                    ),
                    const SizedBox(height: 12),
                    if (isPiper)
                      for (final v in availableVoices)
                        _PiperVoiceTile(
                          voice: v,
                          isActive: tts.activeVoice.id == v.id,
                          onTap: () async {
                            if (tts.activeVoice.id == v.id) {
                              Navigator.pop(ctx);
                              return;
                            }
                            Navigator.pop(ctx);
                            setState(() => _isSwitchingVoice = true);
                            await tts.switchVoice(v);
                            if (mounted) setState(() => _isSwitchingVoice = false);
                          },
                        )
                    else if (tts.flutterTtsVoices.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 28),
                        child: Center(
                          child: Text(
                            'No English voices found.\nInstall voices in system settings.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 15),
                          ),
                        ),
                      )
                    else
                      for (final v in tts.flutterTtsVoices)
                        _FlutterTtsVoiceTile(
                          voice: v,
                          isActive: tts.activeFTtsVoice?.id == v.id,
                          onTap: () async {
                            await tts.switchFlutterTtsVoice(v);
                            setSheet(() {});
                            setState(() {});
                          },
                        ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Text settings sheet ───────────────────────────────────────
  void _openTextSettings() {
    final mq = MediaQuery.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 20,
            bottom: mq.viewInsets.bottom + 24,
          ),
          child: StatefulBuilder(
            builder: (context, setSheet) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sheetHandle(),
                const Text('Text settings',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                _SheetSliderRow(
                  label: 'Font size',
                  valueLabel: '${_fontSize.round()}px',
                  child: Slider(
                    value: _fontSize, min: 14, max: 32, divisions: 18,
                    activeColor: const Color(0xFF38616A),
                    label: '${_fontSize.round()}px',
                    onChanged: (v) {
                      setSheet(() => _fontSize = v);
                      setState(() => _fontSize = v);
                    },
                  ),
                ),
                _SheetSliderRow(
                  label: 'Line spacing',
                  valueLabel: _lineHeight.toStringAsFixed(1),
                  child: Slider(
                    value: _lineHeight, min: 1.4, max: 3.2, divisions: 18,
                    activeColor: const Color(0xFF38616A),
                    label: _lineHeight.toStringAsFixed(1),
                    onChanged: (v) {
                      setSheet(() => _lineHeight = v);
                      setState(() => _lineHeight = v);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 110,
                        child: Text('Font weight',
                            style: TextStyle(fontSize: 15)),
                      ),
                      Expanded(
                        child: Wrap(
                          spacing: 10,
                          children: [
                            _weightChip('Regular', FontWeight.w400, setSheet),
                            _weightChip('Medium',  FontWeight.w500, setSheet),
                            _weightChip('Bold',    FontWeight.w700, setSheet),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    const SizedBox(
                        width: 110,
                        child: Text('Focus mode',
                            style: TextStyle(fontSize: 15))),
                    Switch(
                      value: _focusMode,
                      activeColor: const Color(0xFF38616A),
                      onChanged: (v) {
                        setSheet(() => _focusMode = v);
                        setState(() => _focusMode = v);
                      },
                    ),
                    Flexible(
                      child: Text(
                        _focusMode ? 'Dim others' : 'Highlight only',
                        style: const TextStyle(
                            fontSize: 13, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Flexible(
                      child: Text('Reset to defaults',
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey)),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        setSheet(() {
                          _fontSize   = _defaultFontSize;
                          _lineHeight = _defaultLineHeight;
                          _fontWeight = _defaultFontWeight;
                          _focusMode  = false;
                        });
                        await _resetToDefaults();
                      },
                      icon: const Icon(Icons.refresh,
                          size: 18, color: Color(0xFF38616A)),
                      label: const Text('Reset',
                          style: TextStyle(
                              color: Color(0xFF38616A), fontSize: 15)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _weightChip(String label, FontWeight weight, StateSetter setSheet) {
    final selected = _fontWeight == weight;
    return GestureDetector(
      onTap: () {
        setSheet(() => _fontWeight = weight);
        setState(() => _fontWeight = weight);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF38616A) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 14,
              color: selected ? Colors.white : Colors.black87,
              fontWeight: weight,
            )),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final fileName   = widget.filePath.split('/').last;
    final tts        = PiperTtsService();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Stack(
        children: [
          // ── Main scaffold ────────────────────────────────────
          Scaffold(
            backgroundColor: const Color(0xFFE8EDEF),
            appBar: AppBar(
              backgroundColor: const Color(0xFF38616A),
              foregroundColor: Colors.white,
              toolbarHeight: 64,
              title: Text(
                fileName,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, size: 28),
                onPressed: _handleBack,
              ),
            ),
            body: !_loaded
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      // Read-selection progress banner
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, anim) => SizeTransition(
                          sizeFactor: anim,
                          axisAlignment: -1,
                          child: FadeTransition(opacity: anim, child: child),
                        ),
                        child: (controller.isReadMode &&
                                controller.readSentences.isNotEmpty)
                            ? _ReadProgressBanner(
                                key: const ValueKey('banner'),
                                sentences: controller.readSentences,
                                currentIndex: controller.readSentenceIndex,
                                isPlaying: controller.isPlaying,
                                onStop: () => controller.stop(_refresh),
                              )
                            : const SizedBox.shrink(
                                key: ValueKey('empty')),
                      ),
                      Expanded(child: _buildTextView()),
                      _buildBottomBar(),
                    ],
                  ),
          ),

          // ── Voice Command FAB (bottom-left) ──────────────────
          if (_loaded)
            Positioned(
              bottom: _bottomBarHeight + safeBottom + 40 + _kFabBottomOffset,
              left: _kFabLeftOffset,
              child: _VoiceCommandFab(
                isPlaying: controller.isPlaying,
                isLoaded: _loaded,
                onPlay: _handlePlayPause,
                onPause: _handlePlayPause,
                onStop: () => controller.stop(() {
                  if (mounted) setState(() {});
                }),
                voices: availableVoices,
                activeVoiceId: tts.activeVoice.id,
                onSelectVoice: (voice) async {
                  setState(() => _isSwitchingVoice = true);
                  await tts.switchVoice(voice);
                  if (mounted) setState(() => _isSwitchingVoice = false);
                },
                onOpenVoiceSelector: _openVoiceSelector,
                onRefresh: () {
                  if (mounted) setState(() {});
                },
                getSelectedText: () => _selectedText,
                onReadSelection: _startReadSelection,
                documentSentences: controller.sentences,
              ),
            ),

          // ── Re-select FAB (bottom-right) ─────────────────────
          if (_showReselect)
            Positioned(
              bottom: _bottomBarHeight + safeBottom + _kFabBottomOffset,
              right: _kFabRightOffset,
              child: _ReselectFab(onTap: _reselect),
            ),

          // ── Voice switching overlay ───────────────────────────
          if (_isSwitchingVoice) const _VoiceSwitchingOverlay(),
        ],
      ),
    );
  }

  // ── Text view ─────────────────────────────────────────────────
  Widget _buildTextView() {
    if (controller.sentences.isEmpty) {
      return const Center(
        child: Text('No text found in this file.',
            style: TextStyle(color: Colors.grey, fontSize: 18)),
      );
    }

    return SelectionArea(
      onSelectionChanged: (v) =>
          _selectedText = v?.plainText ?? '',
      contextMenuBuilder: (context, state) =>
          AdaptiveTextSelectionToolbar(
        anchors: state.contextMenuAnchors,
        children: [
          TextSelectionToolbarTextButton(
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 12),
            onPressed: () {
              state.copySelection(SelectionChangedCause.toolbar);
              state.hideToolbar();
            },
            child: const Text('Copy', style: TextStyle(fontSize: 16)),
          ),
          TextSelectionToolbarTextButton(
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 12),
            onPressed: () =>
                state.selectAll(SelectionChangedCause.toolbar),
            child: const Text('Select all', style: TextStyle(fontSize: 16)),
          ),
          TextSelectionToolbarTextButton(
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 12),
            onPressed: () {
              state.hideToolbar();
              final t = _selectedText.trim();
              if (t.isNotEmpty) _startReadSelection(t);
            },
            child: const Text('Read',
                style: TextStyle(
                    color: Color(0xFF38616A),
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
          ),
        ],
      ),
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: _showReselect ? _bottomBarHeight + 80 : 24,
        ),
        itemCount: controller.sentences.length,
        itemBuilder: (context, i) => _buildSentenceTile(i),
      ),
    );
  }

  Widget _buildSentenceTile(int index) {
    final sentence = controller.sentences[index];
    final bool activePlaying =
        controller.isPlaying && !controller.isReadMode;
    final bool reading =
        activePlaying && controller.currentSentenceIndex == index;

    Color? bg;
    if (reading) {
      bg = const Color(0xFF1D9E75).withOpacity(_focusMode ? 0.28 : 0.20);
    } else if (_focusMode && activePlaying) {
      bg = Colors.black.withOpacity(0.03);
    }

    final double opacity =
        _focusMode && activePlaying && !reading ? 0.28 : 1.0;

    return AnimatedContainer(
      key: _sentenceKeys.length > index ? _sentenceKeys[index] : null,
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: reading
            ? Border.all(color: const Color(0xFF1D9E75), width: 2)
            : null,
      ),
      child: Opacity(
        opacity: opacity,
        child: Text(
          sentence,
          style: TextStyle(
            fontSize: _fontSize,
            height: _lineHeight,
            fontWeight: reading ? FontWeight.w700 : _fontWeight,
            color: reading ? const Color(0xFF0F6E56) : Colors.black87,
          ),
        ),
      ),
    );
  }

  // ── Bottom bar ────────────────────────────────────────────────
  Widget _buildBottomBar() {
    final tts       = PiperTtsService();
    final showPitch = tts.engine == TtsEngine.flutterTts;
    final defSpeed  = controller.speed == AnalyzeController.defaultSpeed;
    final defPitch  = controller.pitch == AnalyzeController.defaultPitch;
    final allDefault = defSpeed && (!showPitch || defPitch);

    return SafeArea(
      top: false,
      child: Container(
        key: _bottomBarKey,
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _BarBtn(
                  icon: Icons.text_fields,
                  label: 'Text',
                  color: const Color(0xFF38616A),
                  filled: true,
                  onTap: _openTextSettings,
                ),
                _BarDivider(),
                _BarBtn(
                  icon: Icons.stop_rounded,
                  label: 'Stop',
                  color: const Color(0xFF38616A),
                  filled: false,
                  onTap: () => controller.stop(() {
                    if (mounted) setState(() {});
                  }),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: ElevatedButton.icon(
                      onPressed: _handlePlayPause,
                      icon: Icon(
                        controller.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 28,
                      ),
                      label: Text(
                        controller.isPlaying ? 'Pause' : 'Play',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF38616A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ),
                _BarBtn(
                  icon: _focusMode
                      ? Icons.center_focus_strong
                      : Icons.center_focus_weak,
                  label: 'Focus',
                  color: _focusMode
                      ? const Color(0xFF1D9E75)
                      : Colors.grey,
                  filled: false,
                  onTap: () => setState(() => _focusMode = !_focusMode),
                ),
                _BarDivider(),
                _BarBtn(
                  icon: Icons.record_voice_over,
                  label: 'Voice',
                  color: const Color(0xFF1D9E75),
                  filled: true,
                  onTap: _openVoiceSelector,
                ),
              ],
            ),
            const SizedBox(height: 6),
            _SliderRow(
              icon: Icons.speed,
              label: 'Speed',
              value: controller.speed,
              min: AnalyzeController.minSpeed,
              max: AnalyzeController.maxSpeed,
              defaultValue: AnalyzeController.defaultSpeed,
              divisions: 6,
              displayText: '${controller.speed.toStringAsFixed(1)}x',
              isDefault: defSpeed,
              onChanged: (v) async {
                await controller.setSpeed(v);
                setState(() {});
              },
            ),
            if (showPitch)
              _SliderRow(
                icon: Icons.graphic_eq,
                label: 'Pitch',
                value: controller.pitch,
                min: AnalyzeController.minPitch,
                max: AnalyzeController.maxPitch,
                defaultValue: AnalyzeController.defaultPitch,
                divisions: 10,
                displayText: controller.pitch.toStringAsFixed(1),
                isDefault: defPitch,
                onChanged: (v) async {
                  await controller.setPitch(v);
                  setState(() {});
                },
              ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: allDefault
                  ? const SizedBox.shrink()
                  : TextButton.icon(
                      onPressed: _resetToDefaults,
                      icon: const Icon(Icons.refresh,
                          size: 16, color: Color(0xFF38616A)),
                      label: const Text('Reset to default',
                          style: TextStyle(
                              fontSize: 13, color: Color(0xFF38616A))),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// VOICE COMMAND FAB
// ═══════════════════════════════════════════════════════════════
class _VoiceCommandFab extends StatefulWidget {
  final bool isPlaying;
  final bool isLoaded;
  final VoidCallback onPlay;
  final VoidCallback onPause;
  final VoidCallback onStop;
  final List<VoiceModel> voices;
  final String activeVoiceId;
  final ValueChanged<VoiceModel> onSelectVoice;
  final VoidCallback onRefresh;
  final VoidCallback onOpenVoiceSelector;
  final String Function() getSelectedText;
  final ValueChanged<String> onReadSelection;
  final List<String> documentSentences;

  const _VoiceCommandFab({
    required this.isPlaying,
    required this.isLoaded,
    required this.onPlay,
    required this.onPause,
    required this.onStop,
    required this.voices,
    required this.activeVoiceId,
    required this.onSelectVoice,
    required this.onRefresh,
    required this.onOpenVoiceSelector,
    required this.getSelectedText,
    required this.onReadSelection,
    required this.documentSentences,
  });

  @override
  State<_VoiceCommandFab> createState() => _VoiceCommandFabState();
}

class _VoiceCommandFabState extends State<_VoiceCommandFab> {
  bool   _isListening       = false;
  String _spokenText        = '';
  bool   _awaitingVoicePick = false;
  String _bubbleText        = '';

  bool _wasPlayingBeforeMenu = false;

  // ── Stream subscriptions to cancel on dispose ─────────────────
  StreamSubscription<String>? _textSub;
  StreamSubscription<String>? _cmdSub;
  StreamSubscription<bool>?   _stateSub;

  @override
  void initState() {
    super.initState();

    _textSub = SpeechRecognitionService.instance.textStream.listen((text) {
      if (!mounted) return;
      setState(() => _spokenText = text);
    });

    _cmdSub = SpeechRecognitionService.instance.commandStream.listen((text) {
      if (!mounted) return;
      final upper = text.toUpperCase().trim();
      if (_awaitingVoicePick) {
        _handleVoicePickResponse(upper);
      } else {
        _handleVoiceCommand(upper);
      }
      // ── Auto-stop listening after command recognized ──────────
      _stopMic();
    });

    _stateSub = SpeechRecognitionService.instance.stateStream.listen((rec) {
      if (!mounted) return;
      setState(() => _isListening = rec);
    });
  }

  @override
  void dispose() {
    _textSub?.cancel();
    _cmdSub?.cancel();
    _stateSub?.cancel();
    super.dispose();
  }

void _handleVoiceCommand(String upper) {
    if (upper.contains('STOP')) {
      widget.onStop();
      widget.onRefresh();
      _showBubble('Stopped.');

    } else if (upper.contains('PAUSE')) {
      if (widget.isPlaying) {
        widget.onPause();
        widget.onRefresh();
        _showBubble('Paused.');
      }

    } else if (upper.contains('PLAY') ||
               upper.contains('RESUME') ||
               upper.contains('START') ||
               upper.contains('READ')) {

      if (!widget.isLoaded) {
        _showBubble('Still loading…');
        return;
      }

      final sel = widget.getSelectedText().trim();
      if (sel.isNotEmpty) {
        widget.onReadSelection(sel);
        widget.onRefresh();
        _showBubble('Reading selection.');
        return;
      }

      if (!widget.isPlaying) {
        widget.onPlay();
        widget.onRefresh();
        _showBubble('Playing document.');
      }

    } else if (upper.contains('VOICE') ||
               upper.contains('SWITCH') ||
               upper.contains('CHANGE')) {
      _startVoiceMenu();

    } else if (upper.contains('CLOSE') || upper.contains('BACK')) {
      // ← new: lets user dismiss any open dialog by voice
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _startVoiceMenu() async {
    final tts    = PiperTtsService();
    final voices = widget.voices;
    if (voices.isEmpty) return;

    _wasPlayingBeforeMenu = widget.isPlaying;
    if (_wasPlayingBeforeMenu) {
      widget.onPause();
      widget.onRefresh();
    }

    final parts = <String>[];
    for (int i = 0; i < voices.length; i++) {
      parts.add('Say ${i + 1} for ${voices[i].label}');
    }
    final menuSpeech =
        'Which voice would you like? ${parts.join(', ')}.';

    final bubbleParts = <String>[];
    for (int i = 0; i < voices.length; i++) {
      final active = voices[i].id == widget.activeVoiceId ? ' ✓' : '';
      bubbleParts.add('${i + 1}: ${voices[i].label}$active');
    }

    setState(() {
      _awaitingVoicePick = true;
      _bubbleText = 'Which voice?\n${bubbleParts.join('  •  ')}';
    });

    await tts.stop();
    await tts.speak(menuSpeech);

    if (mounted) {
      setState(() => _spokenText = '');
      SpeechRecognitionService.instance.startRecording();
    }
  }

  Future<void> _handleVoicePickResponse(String upper) async {
    final tts    = PiperTtsService();
    final voices = widget.voices;

    if (upper.contains('CANCEL') ||
        upper.contains('NEVERMIND') ||
        upper.contains('NEVER MIND')) {
      setState(() {
        _awaitingVoicePick = false;
        _bubbleText        = 'Cancelled.';
      });
      await tts.speak('Voice selection cancelled.');

      if (_wasPlayingBeforeMenu) {
        _wasPlayingBeforeMenu = false;
        widget.onPlay();
        widget.onRefresh();
      }

      _clearBubbleAfter(2);
      return;
    }

    final idx = _resolveVoiceIndex(upper, voices.length);

    if (idx == null) {
      final retry =
          'Sorry, I didn\'t catch that. '
          'Say a number between 1 and ${voices.length}, or say cancel.';

      setState(() => _bubbleText = retry);
      await tts.speak(retry);

      if (mounted) {
        setState(() => _spokenText = '');
        SpeechRecognitionService.instance.startRecording();
      }
      return;
    }

    final chosen = voices[idx];
    setState(() {
      _awaitingVoicePick    = false;
      _wasPlayingBeforeMenu = false;
      _bubbleText           = 'Switching to ${chosen.label}…';
    });

    await tts.speak('Switching to ${chosen.label}.');

    widget.onSelectVoice(chosen);
    widget.onRefresh();

    Future.delayed(const Duration(milliseconds: 900), () async {
      await tts.speak('Hello! I am ${chosen.label}. Voice switched successfully.');
      if (mounted) {
        setState(() => _bubbleText = '✓ ${chosen.label} active');
        _clearBubbleAfter(3);
        widget.onRefresh();
      }
    });
  }

  int? _resolveVoiceIndex(String upper, int count) {
    const words = [
      'ONE', 'TWO', 'THREE', 'FOUR', 'FIVE',
      'SIX', 'SEVEN', 'EIGHT', 'NINE', 'TEN',
    ];
    for (int i = 0; i < words.length && i < count; i++) {
      if (upper.contains(words[i])) return i;
    }

    const ordinals = [
      'FIRST', 'SECOND', 'THIRD', 'FOURTH', 'FIFTH',
      'SIXTH', 'SEVENTH', 'EIGHTH', 'NINTH', 'TENTH',
    ];
    for (int i = 0; i < ordinals.length && i < count; i++) {
      if (upper.contains(ordinals[i])) return i;
    }

    for (int i = 1; i <= count; i++) {
      if (upper.contains('$i')) return i - 1;
    }

    return null;
  }

  void _showBubble(String text) {
    setState(() => _bubbleText = text);
    _clearBubbleAfter(2);
  }

  void _clearBubbleAfter(int seconds) {
    Future.delayed(Duration(seconds: seconds), () {
      if (mounted) setState(() => _bubbleText = '');
    });
  }

  void _startMic() {
    setState(() => _spokenText = '');
    SpeechRecognitionService.instance.startRecording();
  }

  void _stopMic() {
    SpeechRecognitionService.instance.stopRecording();
  }

  void _toggleMic() {
    if (_isListening) {
      _stopMic();
    } else {
      _startMic();
    }
  }

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bubbleVisible = _bubbleText.isNotEmpty || _isListening;
    final bubbleContent = _isListening
        ? (_spokenText.isEmpty ? 'Listening…' : _spokenText)
        : _bubbleText;

    return SizedBox(
      width: 240,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Speech bubble ─────────────────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SizeTransition(
                sizeFactor: anim,
                axisAlignment: 1,
                child: child,
              ),
            ),
            child: bubbleVisible
                ? Container(
                    key: const ValueKey('bubble'),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                      border: Border.all(
                        color: _awaitingVoicePick
                            ? const Color(0xFF1D9E75).withOpacity(0.4)
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      bubbleContent,
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _isListening
                            ? const Color(0xFF1D9E75)
                            : const Color(0xFF38616A),
                        decoration: TextDecoration.none,
                        height: 1.5,
                      ),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('empty')),
          ),

          // ── Mic FAB ───────────────────────────────────────────
          SizedBox(
            width: 64,
            height: 64,
            child: GestureDetector(
              onTap: _toggleMic,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isListening
                      ? Colors.redAccent
                      : _awaitingVoicePick
                          ? const Color(0xFF1D9E75)
                          : const Color(0xFF38616A),
                  boxShadow: [
                    BoxShadow(
                      color: (_isListening
                              ? Colors.redAccent
                              : _awaitingVoicePick
                                  ? const Color(0xFF1D9E75)
                                  : const Color(0xFF38616A))
                          .withOpacity(0.40),
                      blurRadius: _isListening ? 22 : 10,
                      spreadRadius: _isListening ? 5 : 0,
                    ),
                  ],
                ),
                child: Icon(
                  _isListening
                      ? Icons.mic
                      : _awaitingVoicePick
                          ? Icons.record_voice_over
                          : Icons.mic_none,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          ),

          // ── Label ─────────────────────────────────────────────
          const SizedBox(height: 4),
          SizedBox(
            height: 14,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _awaitingVoicePick ? 'Say a number' : 'Tap to talk',
                key: ValueKey(_awaitingVoicePick),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _awaitingVoicePick
                      ? const Color(0xFF1D9E75)
                      : Colors.grey.shade500,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// RE-SELECT FAB
// ═══════════════════════════════════════════════════════════════
class _ReselectFab extends StatelessWidget {
  final VoidCallback onTap;
  const _ReselectFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: const Color(0xFF38616A),
            shape: const CircleBorder(),
            elevation: 4,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Icon(Icons.crop_free, color: Colors.white, size: 28),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF38616A).withOpacity(0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Regional',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF38616A),
                letterSpacing: 0.3,
                decoration: TextDecoration.none,
                decorationColor: Colors.transparent,
              ),
            ),
          ),
          const SizedBox(height: 43),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// BAR BUTTON
// ═══════════════════════════════════════════════════════════════
class _BarBtn extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final Color        color;
  final bool         filled;
  final VoidCallback onTap;

  const _BarBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled ? color : Colors.transparent,
                border: filled
                    ? null
                    : Border.all(color: color, width: 2),
              ),
              child: Icon(icon,
                  size: 24, color: filled ? Colors.white : color),
            ),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 0.2,
                )),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// BAR DIVIDER
// ═══════════════════════════════════════════════════════════════
class _BarDivider extends StatelessWidget {
  const _BarDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: Colors.grey.shade200,
      margin: const EdgeInsets.symmetric(horizontal: 2),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ENGINE TOGGLE
// ═══════════════════════════════════════════════════════════════
class _EngineToggle extends StatelessWidget {
  final TtsEngine               selected;
  final ValueChanged<TtsEngine> onChanged;
  const _EngineToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          _EngineBtn(
            label: 'Piper TTS',
            sublabel: 'Offline · High quality',
            icon: Icons.memory,
            active: selected == TtsEngine.piper,
            onTap: () => onChanged(TtsEngine.piper),
          ),
          Container(width: 1, height: 56, color: Colors.grey.shade200),
          _EngineBtn(
            label: 'Device TTS',
            sublabel: 'System voices',
            icon: Icons.phone_android,
            active: selected == TtsEngine.flutterTts,
            onTap: () => onChanged(TtsEngine.flutterTts),
          ),
        ],
      ),
    );
  }
}

class _EngineBtn extends StatelessWidget {
  final String       label;
  final String       sublabel;
  final IconData     icon;
  final bool         active;
  final VoidCallback onTap;
  const _EngineBtn({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF38616A);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          decoration: BoxDecoration(
            color: active ? accent.withOpacity(0.10) : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 22,
                  color: active ? accent : Colors.grey.shade400),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: active ? accent : Colors.black87)),
                    Text(sublabel,
                        style: TextStyle(
                            fontSize: 11,
                            color: active
                                ? accent.withOpacity(0.7)
                                : Colors.grey)),
                  ],
                ),
              ),
              if (active)
                const Icon(Icons.check_circle, color: accent, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PIPER VOICE TILE
// ═══════════════════════════════════════════════════════════════
class _PiperVoiceTile extends StatelessWidget {
  final VoiceModel   voice;
  final bool         isActive;
  final VoidCallback onTap;
  const _PiperVoiceTile(
      {required this.voice, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF38616A);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: isActive ? accent.withOpacity(0.08) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isActive ? accent : Colors.grey.shade200,
              width: isActive ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isActive ? accent : Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.record_voice_over,
                  size: 24,
                  color: isActive ? Colors.white : Colors.grey.shade500),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(voice.label,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isActive ? accent : Colors.black87)),
                  const SizedBox(height: 2),
                  Text(voice.accent,
                      style: const TextStyle(
                          fontSize: 13, color: Colors.grey)),
                ],
              ),
            ),
            if (isActive)
              const Icon(Icons.check_circle, color: accent, size: 24),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// FLUTTER TTS VOICE TILE
// ═══════════════════════════════════════════════════════════════
class _FlutterTtsVoiceTile extends StatelessWidget {
  final FlutterTtsVoice voice;
  final bool            isActive;
  final VoidCallback    onTap;
  const _FlutterTtsVoiceTile(
      {required this.voice, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF38616A);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? accent.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isActive ? accent : Colors.grey.shade200,
              width: isActive ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isActive
                    ? accent.withOpacity(0.15)
                    : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.phone_android,
                  size: 20,
                  color: isActive ? accent : Colors.grey.shade400),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(voice.label,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isActive ? accent : Colors.black87),
                      overflow: TextOverflow.ellipsis),
                  Text(voice.locale,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            if (isActive)
              const Icon(Icons.check_circle, color: accent, size: 22),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// VOICE SWITCHING OVERLAY
// ═══════════════════════════════════════════════════════════════
class _VoiceSwitchingOverlay extends StatefulWidget {
  const _VoiceSwitchingOverlay();

  @override
  State<_VoiceSwitchingOverlay> createState() =>
      _VoiceSwitchingOverlayState();
}

class _VoiceSwitchingOverlayState extends State<_VoiceSwitchingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.90, end: 1.08).animate(
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
    return Container(
      color: Colors.black.withOpacity(0.52),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
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
              ScaleTransition(
                scale: _scale,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF38616A).withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.record_voice_over,
                      color: Color(0xFF38616A), size: 40),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Switching voice...',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.none,
                      color: Color(0xFF38616A))),
              const SizedBox(height: 8),
              const Text('Loading voice model, please wait',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      decoration: TextDecoration.none,
                      fontSize: 14,
                      color: Colors.grey,
                      height: 1.4)),
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
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// READ PROGRESS BANNER
// ═══════════════════════════════════════════════════════════════
class _ReadProgressBanner extends StatelessWidget {
  final List<String> sentences;
  final int          currentIndex;
  final bool         isPlaying;
  final VoidCallback onStop;

  const _ReadProgressBanner({
    super.key,
    required this.sentences,
    required this.currentIndex,
    required this.isPlaying,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final total    = sentences.length;
    final safeIdx  = currentIndex.clamp(0, total - 1);
    final progress = total > 1 ? (safeIdx / (total - 1)) : 1.0;
    final current  = sentences[safeIdx];

    const accent     = Color(0xFF1D9E75);
    const accentDark = Color(0xFF0F6E56);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accent.withOpacity(isPlaying ? 0.14 : 0.07),
            accent.withOpacity(isPlaying ? 0.07 : 0.03),
          ],
        ),
        border: Border(
            bottom: BorderSide(
                color: accent.withOpacity(0.22), width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 10, 0),
            child: Row(
              children: [
                _WaveformIcon(isPlaying: isPlaying),
                const SizedBox(width: 10),
                Text(
                  isPlaying ? 'Reading selection' : 'Paused',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: accentDark.withOpacity(0.75),
                      letterSpacing: 0.5),
                ),
                const SizedBox(width: 8),
                if (total > 1)
                  _PartPill(
                      current: safeIdx + 1,
                      total: total,
                      isPlaying: isPlaying),
                const Spacer(),
                GestureDetector(
                  onTap: onStop,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                        color: accent.withOpacity(0.12),
                        shape: BoxShape.circle),
                    child: Icon(Icons.close_rounded,
                        size: 17,
                        color: accentDark.withOpacity(0.7)),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                current,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isPlaying
                        ? accentDark
                        : accentDark.withOpacity(0.55),
                    height: 1.45),
              ),
            ),
          ),
          if (total > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _ProgressBar(
                  progress: progress, isPlaying: isPlaying),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _PartPill extends StatelessWidget {
  final int  current;
  final int  total;
  final bool isPlaying;
  const _PartPill(
      {required this.current,
      required this.total,
      required this.isPlaying});

  @override
  Widget build(BuildContext context) {
    const accent     = Color(0xFF1D9E75);
    const accentDark = Color(0xFF0F6E56);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isPlaying
            ? accent.withOpacity(0.18)
            : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$current / $total',
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isPlaying ? accentDark : Colors.grey.shade600,
            letterSpacing: 0.2),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double progress;
  final bool   isPlaying;
  const _ProgressBar({required this.progress, required this.isPlaying});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF1D9E75);
    return LayoutBuilder(builder: (context, constraints) {
      return Stack(
        children: [
          Container(
            height: 5,
            width: double.infinity,
            decoration: BoxDecoration(
                color: accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(3)),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: 5,
            width: constraints.maxWidth * progress.clamp(0.0, 1.0),
            decoration: BoxDecoration(
                color: isPlaying ? accent : accent.withOpacity(0.45),
                borderRadius: BorderRadius.circular(3)),
          ),
        ],
      );
    });
  }
}

class _WaveformIcon extends StatefulWidget {
  final bool isPlaying;
  const _WaveformIcon({required this.isPlaying});

  @override
  State<_WaveformIcon> createState() => _WaveformIconState();
}

class _WaveformIconState extends State<_WaveformIcon>
    with TickerProviderStateMixin {
  late final List<AnimationController> _bars;
  late final List<Animation<double>>   _heights;

  static const _delays = [0.0, 0.2, 0.4];
  static const _mins   = [0.35, 0.55, 0.25];
  static const _maxs   = [1.0,  0.75, 0.9];

  @override
  void initState() {
    super.initState();
    _bars = List.generate(3, (i) {
      final c = AnimationController(
          vsync: this,
          duration: Duration(milliseconds: 420 + i * 80));
      if (widget.isPlaying) {
        Future.delayed(
            Duration(milliseconds: (_delays[i] * 300).round()),
            () { if (mounted) c.repeat(reverse: true); });
      }
      return c;
    });
    _heights = List.generate(3, (i) {
      return Tween<double>(begin: _mins[i], end: _maxs[i]).animate(
          CurvedAnimation(parent: _bars[i], curve: Curves.easeInOut));
    });
  }

  @override
  void didUpdateWidget(_WaveformIcon old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying != old.isPlaying) {
      for (final c in _bars) {
        if (widget.isPlaying) {
          c.repeat(reverse: true);
        } else {
          c.animateTo(0.3,
              duration: const Duration(milliseconds: 200));
        }
      }
    }
  }

  @override
  void dispose() {
    for (final c in _bars) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF1D9E75);
    const maxH   = 16.0;
    const barW   = 3.5;

    return SizedBox(
      width: 20,
      height: maxH,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _heights[i],
            builder: (_, __) {
              final h = (maxH * _heights[i].value).clamp(3.0, maxH);
              return AnimatedContainer(
                duration: const Duration(milliseconds: 80),
                width: barW,
                height: h,
                decoration: BoxDecoration(
                  color: widget.isPlaying
                      ? accent
                      : accent.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SHEET SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════
Widget _sheetHandle() => Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );

class _SheetSliderRow extends StatelessWidget {
  final String label;
  final String valueLabel;
  final Widget child;
  const _SheetSliderRow(
      {required this.label,
      required this.valueLabel,
      required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(fontSize: 15))),
        Expanded(child: child),
        SizedBox(
          width: 44,
          child: Text(valueLabel,
              style: const TextStyle(fontSize: 14),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  final IconData             icon;
  final String               label;
  final double               value;
  final double               min;
  final double               max;
  final double               defaultValue;
  final int                  divisions;
  final String               displayText;
  final bool                 isDefault;
  final ValueChanged<double>  onChanged;

  const _SliderRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.defaultValue,
    required this.divisions,
    required this.displayText,
    required this.isDefault,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 4),
        SizedBox(
          width: 52,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.grey)),
              if (isDefault)
                Container(
                  margin: const EdgeInsets.only(top: 1),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38616A).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Text('DEF',
                      style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF38616A))),
                ),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  showValueIndicator: ShowValueIndicator.always,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 10.0,
                    pressedElevation: 8.0,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 20.0,
                  ),
                  trackHeight: 4.0,
                ),
                child: Slider(
                  value: value,
                  min: min,
                  max: max,
                  divisions: divisions,
                  activeColor: const Color(0xFF38616A),
                  inactiveColor: Colors.grey.shade200,
                  label: displayText,
                  onChanged: onChanged,
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _DefaultMarkerPainter(
                      min: min,
                      max: max,
                      defaultValue: defaultValue,
                      isAtDefault: isDefault,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            displayText,
            style: TextStyle(
              fontSize: 12,
              color: isDefault
                  ? const Color(0xFF38616A)
                  : Colors.grey,
              fontWeight: isDefault
                  ? FontWeight.w700
                  : FontWeight.normal,
            ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _DefaultMarkerPainter extends CustomPainter {
  final double min;
  final double max;
  final double defaultValue;
  final bool   isAtDefault;

  const _DefaultMarkerPainter({
    required this.min,
    required this.max,
    required this.defaultValue,
    required this.isAtDefault,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double pad    = 24.0;
    final double trackW = size.width - pad * 2;
    final double fraction =
        (defaultValue - min) / (max - min);
    final double x  = pad + fraction * trackW;
    final double cy = size.height / 2;

    final paint = Paint()
      ..color = isAtDefault
          ? const Color(0xFF38616A)
          : const Color(0xFF38616A).withOpacity(0.35)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(x, cy + 7), Offset(x, cy + 14), paint);

    final tp = TextPainter(
      text: TextSpan(
        text: 'def',
        style: TextStyle(
          fontSize: 8,
          color: isAtDefault
              ? const Color(0xFF38616A)
              : const Color(0xFF38616A).withOpacity(0.4),
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x - tp.width / 2, cy + 15));
  }

  @override
  bool shouldRepaint(_DefaultMarkerPainter old) =>
      old.defaultValue != defaultValue ||
      old.isAtDefault  != isAtDefault;
}