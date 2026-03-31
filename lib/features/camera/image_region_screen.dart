import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'
    as mlkit;

import '../../core/history/history_store.dart';
import '../analyze/analyze_screen.dart';

class ImageRegionScreen extends StatefulWidget {
  final File imageFile;
  final bool backToHome;

  const ImageRegionScreen({
    super.key,
    required this.imageFile,
    this.backToHome = false,
  });

  @override
  State<ImageRegionScreen> createState() => _ImageRegionScreenState();
}

class _ImageRegionScreenState extends State<ImageRegionScreen> {
  ui.Image? _uiImage;
  Uint8List? _imageBytes;
  bool _imageLoaded = false;
  bool _isProcessing = false;
  bool _showBlocks = true;

  List<_Block> _allBlocks = [];

  Offset? _selectionStart;
  Offset? _selectionEnd;
  bool _hasSelection = false;

  _Handle? _activeHandle;
  Offset _lastMovePos = Offset.zero;
  static const double _handleRadius = 20.0;

  final TransformationController _transformationController =
      TransformationController();

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    _imageBytes = await widget.imageFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(_imageBytes!);
    final frame = await codec.getNextFrame();
    _uiImage = frame.image;
    await _runOcr();
  }

  Future<void> _runOcr() async {
    final input = mlkit.InputImage.fromFile(widget.imageFile);
    final recognizer = mlkit.TextRecognizer();
    final result = await recognizer.processImage(input);
    await recognizer.close();

    final imgW = _uiImage!.width.toDouble();
    final imgH = _uiImage!.height.toDouble();

    final blocks = <_Block>[];
    for (final block in result.blocks) {
      final r = block.boundingBox;
      blocks.add(_Block(
        text: block.text,
        rect: Rect.fromLTRB(
          r.left / imgW,
          r.top / imgH,
          r.right / imgW,
          r.bottom / imgH,
        ),
      ));
    }

    if (mounted) {
      setState(() {
        _allBlocks = blocks;
        _imageLoaded = true;
      });
    }
  }

  _Handle? _hitHandle(Offset pos) {
    if (_selectionStart == null || _selectionEnd == null) return null;
    final rect = Rect.fromPoints(_selectionStart!, _selectionEnd!);
    final corners = {
      _Handle.topLeft: rect.topLeft,
      _Handle.topRight: rect.topRight,
      _Handle.bottomLeft: rect.bottomLeft,
      _Handle.bottomRight: rect.bottomRight,
    };
    for (final entry in corners.entries) {
      if ((pos - entry.value).distance <= _handleRadius) {
        return entry.key;
      }
    }
    if (rect.contains(pos)) return _Handle.move;
    return null;
  }

  void _onPanStart(DragStartDetails d) {
    final handle = _hitHandle(d.localPosition);
    if (handle != null) {
      _activeHandle = handle;
      _lastMovePos = d.localPosition;
    } else {
      _activeHandle = null;
      setState(() {
        _selectionStart = d.localPosition;
        _selectionEnd = d.localPosition;
        _hasSelection = false;
      });
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_activeHandle == null) {
      setState(() => _selectionEnd = d.localPosition);
      return;
    }
    final delta = d.localPosition - _lastMovePos;
    _lastMovePos = d.localPosition;
    setState(() {
      switch (_activeHandle!) {
        case _Handle.topLeft:
          _selectionStart = _selectionStart! + delta;
          break;
        case _Handle.topRight:
          _selectionStart = Offset(
              _selectionStart!.dx,
              _selectionStart!.dy + delta.dy);
          _selectionEnd = Offset(
              _selectionEnd!.dx + delta.dx,
              _selectionEnd!.dy);
          break;
        case _Handle.bottomLeft:
          _selectionStart = Offset(
              _selectionStart!.dx + delta.dx,
              _selectionStart!.dy);
          _selectionEnd = Offset(
              _selectionEnd!.dx,
              _selectionEnd!.dy + delta.dy);
          break;
        case _Handle.bottomRight:
          _selectionEnd = _selectionEnd! + delta;
          break;
        case _Handle.move:
          _selectionStart = _selectionStart! + delta;
          _selectionEnd = _selectionEnd! + delta;
          break;
      }
    });
  }

  void _onPanEnd(DragEndDetails d) {
    if (_selectionStart != null && _selectionEnd != null) {
      setState(() => _hasSelection = true);
    }
    _activeHandle = null;
  }

  void _resetSelection() {
    setState(() {
      _selectionStart = null;
      _selectionEnd = null;
      _hasSelection = false;
    });
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  Rect? get _selectionRect {
    if (_selectionStart == null || _selectionEnd == null) return null;
    return Rect.fromPoints(_selectionStart!, _selectionEnd!);
  }

  String _extractSelectedText(Rect selectionRect, Size widgetSize) {
    final normalized = Rect.fromLTRB(
      selectionRect.left / widgetSize.width,
      selectionRect.top / widgetSize.height,
      selectionRect.right / widgetSize.width,
      selectionRect.bottom / widgetSize.height,
    );
    final selected = _allBlocks
        .where((b) => b.rect.overlaps(normalized))
        .toList();
    if (selected.isEmpty) return '';
    return selected.map((b) => b.text).join('\n\n');
  }

  Future<void> _confirm(Size widgetSize) async {
    setState(() => _isProcessing = true);

    final text = _hasSelection && _selectionRect != null
        ? _extractSelectedText(_selectionRect!, widgetSize)
        : _allBlocks.map((b) => b.text).join('\n\n');

    final fileName =
        'Camera_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await HistoryStore.add(fileName, widget.imageFile.path);

    if (!mounted) return;
    setState(() => _isProcessing = false);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => AnalyzeScreen(
          filePath: widget.imageFile.path,
          overrideText: text.isEmpty ? null : text,
          backToHome: true,
          sourceImageFile: widget.imageFile,
        ),
      ),
    );
  }

  void _goHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goHome();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: const Color(0xFF38616A),
          foregroundColor: Colors.white,
          title: const Text(
            'Select region',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _goHome,
          ),
          actions: [
            IconButton(
              icon: Icon(
                  _showBlocks ? Icons.grid_on : Icons.grid_off),
              tooltip: 'Toggle text blocks',
              onPressed: () =>
                  setState(() => _showBlocks = !_showBlocks),
            ),
          ],
        ),
        body: !_imageLoaded
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Scanning image...',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 16),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  // Instruction banner
                  Container(
                    width: double.infinity,
                    color: Colors.white.withOpacity(0.08),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Text(
                      _hasSelection
                          ? 'Drag corners to resize · drag inside to move · Reset to clear'
                          : 'Pinch to zoom · single finger drag to select region',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final widgetSize = Size(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        );
                        return Stack(
                          fit: StackFit.expand,
                          children: [

                            // ─── Zoomable image ───────────
                            InteractiveViewer(
                              transformationController:
                                  _transformationController,
                              panEnabled: false,
                              scaleEnabled: true,
                              minScale: 1.0,
                              maxScale: 6.0,
                              child: Image.memory(
                                _imageBytes!,
                                fit: BoxFit.contain,
                                width: constraints.maxWidth,
                                height: constraints.maxHeight,
                              ),
                            ),

                            // ─── Selection overlay ────────
                            // Sits on top, captures single
                            // finger gestures for selection
                            GestureDetector(
                              onPanStart: _onPanStart,
                              onPanUpdate: _onPanUpdate,
                              onPanEnd: _onPanEnd,
                              child: CustomPaint(
                                painter: _OverlayPainter(
                                  blocks: _showBlocks
                                      ? _allBlocks
                                      : [],
                                  selectionRect: _selectionRect,
                                  confirmed: _hasSelection,
                                ),
                                child: const SizedBox.expand(),
                              ),
                            ),

                            // ─── Reset zoom pill ──────────
                            Positioned(
                              top: 12,
                              right: 12,
                              child: GestureDetector(
                                onTap: _resetZoom,
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black
                                        .withOpacity(0.55),
                                    borderRadius:
                                        BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.zoom_out_map,
                                          color: Colors.white70,
                                          size: 16),
                                      SizedBox(width: 4),
                                      Text(
                                        'Reset zoom',
                                        style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // ─── Extract button ───────────
                            Positioned(
                              bottom: 16,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: _buildExtractButton(
                                    widgetSize),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  _buildBottomBar(),
                ],
              ),
      ),
    );
  }

  Widget _buildExtractButton(Size widgetSize) {
    return ElevatedButton.icon(
      onPressed:
          _isProcessing ? null : () => _confirm(widgetSize),
      icon: _isProcessing
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.text_snippet, size: 22),
      label: Text(
        _isProcessing
            ? 'Processing...'
            : _hasSelection
                ? 'Extract region'
                : 'Extract all',
        style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF38616A),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(
            horizontal: 28, vertical: 14),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      color: const Color(0xFF1A1A1A),
      padding: const EdgeInsets.symmetric(
          horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton.icon(
            onPressed: _resetSelection,
            icon:
                const Icon(Icons.clear, color: Colors.white70),
            label: const Text(
              'Reset selection',
              style: TextStyle(
                  color: Colors.white70, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── HANDLE ENUM ──────────────────────────────────────────────
enum _Handle { topLeft, topRight, bottomLeft, bottomRight, move }

// ─── DATA MODEL ───────────────────────────────────────────────
class _Block {
  final String text;
  final Rect rect;
  const _Block({required this.text, required this.rect});
}

// ─── COMBINED OVERLAY PAINTER ─────────────────────────────────
class _OverlayPainter extends CustomPainter {
  final List<_Block> blocks;
  final Rect? selectionRect;
  final bool confirmed;

  const _OverlayPainter({
    required this.blocks,
    required this.selectionRect,
    required this.confirmed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Text blocks
    if (blocks.isNotEmpty) {
      final fill = Paint()
        ..color = const Color(0xFF1D9E75).withOpacity(0.2)
        ..style = PaintingStyle.fill;
      final border = Paint()
        ..color = const Color(0xFF1D9E75).withOpacity(0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      for (final block in blocks) {
        final rect = Rect.fromLTRB(
          block.rect.left * size.width,
          block.rect.top * size.height,
          block.rect.right * size.width,
          block.rect.bottom * size.height,
        );
        canvas.drawRect(rect, fill);
        canvas.drawRect(rect, border);
      }
    }

    // Selection
    if (selectionRect != null) {
      final dimPaint = Paint()
        ..color = Colors.black.withOpacity(0.5)
        ..style = PaintingStyle.fill;
      final path = Path()
        ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
        ..addRect(selectionRect!)
        ..fillType = PathFillType.evenOdd;
      canvas.drawPath(path, dimPaint);

      final borderPaint = Paint()
        ..color = confirmed
            ? const Color(0xFF1D9E75)
            : Colors.white.withOpacity(0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawRect(selectionRect!, borderPaint);

      final handleFill = Paint()
        ..color = confirmed
            ? const Color(0xFF1D9E75)
            : Colors.white
        ..style = PaintingStyle.fill;
      final handleBorder = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      for (final corner in [
        selectionRect!.topLeft,
        selectionRect!.topRight,
        selectionRect!.bottomLeft,
        selectionRect!.bottomRight,
      ]) {
        canvas.drawCircle(corner, 8.0, handleFill);
        canvas.drawCircle(corner, 8.0, handleBorder);
      }
    }
  }

  @override
  bool shouldRepaint(_OverlayPainter old) =>
      old.blocks != blocks ||
      old.selectionRect != selectionRect ||
      old.confirmed != confirmed;
}