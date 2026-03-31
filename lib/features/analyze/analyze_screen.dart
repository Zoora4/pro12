import 'dart:io';
import 'package:flutter/material.dart';

import '../camera/image_region_screen.dart';
import 'analyze_controller.dart';

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

class _AnalyzeScreenState extends State<AnalyzeScreen> {
  late AnalyzeController controller;
  bool _isExiting = false;
  bool _loaded = false;

  // Text customization
  double _fontSize = 15;
  double _lineHeight = 1.8;
  FontWeight _fontWeight = FontWeight.w400;

  // Highlight mode
  bool _focusMode = false; // false = green highlight, true = dim others

  // Tap-highlighted sentences (manual)
  final Set<int> _tappedSentences = {};

  // ScrollController for auto-scroll
  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _sentenceKeys = [];

  @override
  void initState() {
    super.initState();
    controller = AnalyzeController();
    _init();
  }

  Future<void> _init() async {
    await controller.loadFile(
      widget.filePath,
      overrideText: widget.overrideText,
    );
    // Build a key for each sentence
    _sentenceKeys.clear();
    for (int i = 0; i < controller.sentences.length; i++) {
      _sentenceKeys.add(GlobalKey());
    }
    if (mounted) setState(() => _loaded = true);
  }

  String get _ext => widget.filePath.split('.').last.toLowerCase();
  bool get _isImage => ['jpg', 'jpeg', 'png'].contains(_ext);

  void _handleBack() {
    if (_isExiting) return;
    _isExiting = true;
    controller.dispose();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _reselect() {
    controller.dispose();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ImageRegionScreen(
          imageFile: widget.sourceImageFile!,
          backToHome: true,
        ),
      ),
    );
  }

  // Auto-scroll to current sentence
  void _scrollToSentence(int index) {
    if (index >= _sentenceKeys.length) return;
    final key = _sentenceKeys[index];
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      alignment: 0.3,
    );
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
      // Auto-scroll to current sentence when playing
      if (controller.isPlaying) {
        _scrollToSentence(controller.currentSentenceIndex);
      }
    }
  }

  @override
  void dispose() {
    controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ─── TEXT SETTINGS BOTTOM SHEET ───────────────────────────────
  void _openTextSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Text settings',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 24),

                // Font size
                Row(
                  children: [
                    const SizedBox(
                      width: 110,
                      child: Text('Font size',
                          style: TextStyle(fontSize: 14)),
                    ),
                    Expanded(
                      child: Slider(
                        value: _fontSize,
                        min: 12,
                        max: 28,
                        divisions: 16,
                        activeColor: const Color(0xFF38616A),
                        label: '${_fontSize.round()}px',
                        onChanged: (v) {
                          setSheetState(() => _fontSize = v);
                          setState(() => _fontSize = v);
                        },
                      ),
                    ),
                    SizedBox(
                      width: 36,
                      child: Text(
                        '${_fontSize.round()}',
                        style: const TextStyle(fontSize: 13),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),

                // Line spacing
                Row(
                  children: [
                    const SizedBox(
                      width: 110,
                      child: Text('Line spacing',
                          style: TextStyle(fontSize: 14)),
                    ),
                    Expanded(
                      child: Slider(
                        value: _lineHeight,
                        min: 1.2,
                        max: 3.0,
                        divisions: 18,
                        activeColor: const Color(0xFF38616A),
                        label: _lineHeight.toStringAsFixed(1),
                        onChanged: (v) {
                          setSheetState(() => _lineHeight = v);
                          setState(() => _lineHeight = v);
                        },
                      ),
                    ),
                    SizedBox(
                      width: 36,
                      child: Text(
                        _lineHeight.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 13),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),

                // Font weight
                Row(
                  children: [
                    const SizedBox(
                      width: 110,
                      child: Text('Font weight',
                          style: TextStyle(fontSize: 14)),
                    ),
                    const SizedBox(width: 8),
                    _weightChip('Regular', FontWeight.w400,
                        setSheetState),
                    const SizedBox(width: 8),
                    _weightChip('Medium', FontWeight.w500,
                        setSheetState),
                    const SizedBox(width: 8),
                    _weightChip('Bold', FontWeight.w700,
                        setSheetState),
                  ],
                ),

                const SizedBox(height: 16),

                // Highlight mode toggle
                Row(
                  children: [
                    const SizedBox(
                      width: 110,
                      child: Text('Focus mode',
                          style: TextStyle(fontSize: 14)),
                    ),
                    Switch(
                      value: _focusMode,
                      activeColor: const Color(0xFF38616A),
                      onChanged: (v) {
                        setSheetState(() => _focusMode = v);
                        setState(() => _focusMode = v);
                      },
                    ),
                    Text(
                      _focusMode ? 'Dim others' : 'Highlight only',
                      style: const TextStyle(
                          fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),

                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _weightChip(String label, FontWeight weight,
      StateSetter setSheetState) {
    final selected = _fontWeight == weight;
    return GestureDetector(
      onTap: () {
        setSheetState(() => _fontWeight = weight);
        setState(() => _fontWeight = weight);
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF38616A)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: selected ? Colors.white : Colors.black87,
            fontWeight: weight,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.filePath.split('/').last;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFE8EDEF),
        appBar: AppBar(
          backgroundColor: const Color(0xFF38616A),
          foregroundColor: Colors.white,
          title: Text(
            fileName,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.text_fields),
              tooltip: 'Text settings',
              onPressed: _openTextSettings,
            ),
          ],
        ),
        floatingActionButton:
            _isImage && widget.sourceImageFile != null
                ? FloatingActionButton.extended(
                    onPressed: _reselect,
                    backgroundColor: const Color(0xFF38616A),
                    foregroundColor: Colors.white,
                    icon: const Icon(Icons.crop_free),
                    label: const Text('Re-select region'),
                  )
                : null,
        body: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(child: _buildTextView()),
                  _buildBottomBar(),
                ],
              ),
      ),
    );
  }

  // ─── TEXT VIEW ────────────────────────────────────────────────
  Widget _buildTextView() {
    if (controller.sentences.isEmpty) {
      return const Center(
        child: Text(
          'No text found in this file.',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: _isImage && widget.sourceImageFile != null
            ? 100
            : 24,
      ),
      itemCount: controller.sentences.length,
      itemBuilder: (context, index) {
        return _buildSentenceTile(index);
      },
    );
  }

  Widget _buildSentenceTile(int index) {
    final sentence = controller.sentences[index];
    final isCurrentlyReading =
        controller.isPlaying &&
        controller.currentSentenceIndex == index;
    final isTapped = _tappedSentences.contains(index);

    // Determine background color
    Color? bgColor;
    if (isCurrentlyReading) {
      bgColor = _focusMode
          ? const Color(0xFF1D9E75).withOpacity(0.25)
          : const Color(0xFF1D9E75).withOpacity(0.18);
    } else if (isTapped) {
      bgColor = const Color(0xFF38616A).withOpacity(0.12);
    } else if (_focusMode && controller.isPlaying) {
      bgColor = Colors.black.withOpacity(0.03);
    }

    // Text opacity for focus mode
    final double textOpacity =
        _focusMode && controller.isPlaying && !isCurrentlyReading
            ? 0.3
            : 1.0;

    return GestureDetector(
      key: _sentenceKeys.length > index
          ? _sentenceKeys[index]
          : null,
      onTap: () {
        // Toggle tap highlight
        setState(() {
          if (_tappedSentences.contains(index)) {
            _tappedSentences.remove(index);
          } else {
            _tappedSentences.add(index);
          }
        });
      },
      onLongPress: () {
        // Long press = read from this sentence
        controller.readFromSentence(index, _refresh);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(
            horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
          border: isCurrentlyReading
              ? Border.all(
                  color: const Color(0xFF1D9E75),
                  width: 1.5,
                )
              : isTapped
                  ? Border.all(
                      color: const Color(0xFF38616A)
                          .withOpacity(0.4),
                      width: 1.0,
                    )
                  : null,
        ),
        child: Opacity(
          opacity: textOpacity,
          child: Text(
            sentence,
            style: TextStyle(
              fontSize: _fontSize,
              height: _lineHeight,
              fontWeight: isCurrentlyReading
                  ? FontWeight.w600
                  : _fontWeight,
              color: isCurrentlyReading
                  ? const Color(0xFF0F6E56)
                  : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  // ─── BOTTOM BAR — TTS controls ────────────────────────────────
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
            top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play / Pause / Stop row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Stop button
              IconButton(
                onPressed: () => controller.stop(_refresh),
                icon: const Icon(Icons.stop_rounded),
                iconSize: 32,
                color: const Color(0xFF38616A),
                tooltip: 'Stop',
              ),

              const SizedBox(width: 8),

              // Play / Pause
              ElevatedButton.icon(
                onPressed: () =>
                    controller.playPause(_refresh),
                icon: Icon(
                  controller.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 26,
                ),
                label: Text(
                  controller.isPlaying ? 'Pause' : 'Play',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38616A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),

              const SizedBox(width: 8),

              // Focus mode toggle
              IconButton(
                onPressed: () =>
                    setState(() => _focusMode = !_focusMode),
                icon: Icon(
                  _focusMode
                      ? Icons.center_focus_strong
                      : Icons.center_focus_weak,
                ),
                iconSize: 28,
                color: _focusMode
                    ? const Color(0xFF1D9E75)
                    : Colors.grey,
                tooltip: 'Toggle focus mode',
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Speed slider
          Row(
            children: [
              const Icon(Icons.speed, size: 16,
                  color: Colors.grey),
              const SizedBox(width: 6),
              const Text('Speed',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey)),
              Expanded(
                child: Slider(
                  value: controller.speed,
                  min: 0.25,
                  max: 1.5,
                  divisions: 10,
                  activeColor: const Color(0xFF38616A),
                  label:
                      '${controller.speed.toStringAsFixed(2)}x',
                  onChanged: (v) async {
                    await controller.setSpeed(v);
                    setState(() {});
                  },
                ),
              ),
              Text(
                '${controller.speed.toStringAsFixed(1)}x',
                style: const TextStyle(
                    fontSize: 12, color: Colors.grey),
              ),
            ],
          ),

          // Pitch slider
          Row(
            children: [
              const Icon(Icons.graphic_eq, size: 16,
                  color: Colors.grey),
              const SizedBox(width: 6),
              const Text('Pitch',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey)),
              Expanded(
                child: Slider(
                  value: controller.pitch,
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  activeColor: const Color(0xFF38616A),
                  label:
                      controller.pitch.toStringAsFixed(1),
                  onChanged: (v) async {
                    await controller.setPitch(v);
                    setState(() {});
                  },
                ),
              ),
              Text(
                controller.pitch.toStringAsFixed(1),
                style: const TextStyle(
                    fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}