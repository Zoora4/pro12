import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'
    as mlkit;

import '../../core/history/history_store.dart';
import '../analyze/analyze_screen.dart';

enum _Mode { select, zoom }

class _WordBlock {
  final String text;
  final Rect rect; // normalized 0..1 relative to image dimensions
  const _WordBlock({required this.text, required this.rect});
}

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

  List<_WordBlock> _wordBlocks = [];
  List<String> _allBlockTexts = [];

  Offset? _selectionStart;
  Offset? _selectionEnd;
  bool _hasSelection = false;

  _Handle? _activeHandle;
  Offset _lastMovePos = Offset.zero;
  static const double _handleRadius = 20.0;

  _Mode _mode = _Mode.select;

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

    final wordBlocks = <_WordBlock>[];
    final blockTexts = <String>[];

    for (final block in result.blocks) {
      blockTexts.add(block.text);
      for (final line in block.lines) {
        for (final element in line.elements) {
          final r = element.boundingBox;
          wordBlocks.add(_WordBlock(
            text: element.text,
            rect: Rect.fromLTRB(
              r.left / imgW,
              r.top / imgH,
              r.right / imgW,
              r.bottom / imgH,
            ),
          ));
        }
      }
    }

    if (mounted) {
      setState(() {
        _wordBlocks = wordBlocks;
        _allBlockTexts = blockTexts;
        _imageLoaded = true;
      });
    }
  }

  // Returns the rect the image occupies in unzoomed widget space.
  Rect _getImageRect(Size widgetSize) {
    final imgW = _uiImage!.width.toDouble();
    final imgH = _uiImage!.height.toDouble();
    final widgetRatio = widgetSize.width / widgetSize.height;
    final imageRatio = imgW / imgH;

    double displayW, displayH, offsetX, offsetY;

    if (imageRatio > widgetRatio) {
      displayW = widgetSize.width;
      displayH = widgetSize.width / imageRatio;
      offsetX = 0;
      offsetY = (widgetSize.height - displayH) / 2;
    } else {
      displayH = widgetSize.height;
      displayW = widgetSize.height * imageRatio;
      offsetX = (widgetSize.width - displayW) / 2;
      offsetY = 0;
    }

    return Rect.fromLTWH(offsetX, offsetY, displayW, displayH);
  }

  /// Transforms a point from zoomed/panned screen space back to
  /// unzoomed widget space by inverting the InteractiveViewer matrix.
  Offset _invertZoom(Offset p) {
    final m = _transformationController.value;
    // Extract scale and translation from the matrix
    final scaleX = m[0];
    final scaleY = m[5];
    final tx = m[12];
    final ty = m[13];
    return Offset(
      (p.dx - tx) / scaleX,
      (p.dy - ty) / scaleY,
    );
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
          _selectionStart =
              Offset(_selectionStart!.dx, _selectionStart!.dy + delta.dy);
          _selectionEnd =
              Offset(_selectionEnd!.dx + delta.dx, _selectionEnd!.dy);
          break;
        case _Handle.bottomLeft:
          _selectionStart =
              Offset(_selectionStart!.dx + delta.dx, _selectionStart!.dy);
          _selectionEnd =
              Offset(_selectionEnd!.dx, _selectionEnd!.dy + delta.dy);
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
    // ── Invert the zoom/pan transform so selection maps correctly ──────────
    // selectionRect corners are in screen space (after zoom/pan is applied).
    // _getImageRect() works in unzoomed widget space. We must undo the
    // InteractiveViewer transform before doing coordinate mapping.
    final unzoomedTL = _invertZoom(selectionRect.topLeft);
    final unzoomedBR = _invertZoom(selectionRect.bottomRight);
    final unzoomedSelection = Rect.fromPoints(unzoomedTL, unzoomedBR);

    final imageRect = _getImageRect(widgetSize);
    final clampedSelection = unzoomedSelection.intersect(imageRect);
    if (clampedSelection.isEmpty) return '';

    // Convert to normalized image coords (0..1)
    final normalized = Rect.fromLTRB(
      (clampedSelection.left - imageRect.left) / imageRect.width,
      (clampedSelection.top - imageRect.top) / imageRect.height,
      (clampedSelection.right - imageRect.left) / imageRect.width,
      (clampedSelection.bottom - imageRect.top) / imageRect.height,
    );

    final selected = <_WordBlock>[];
    for (final word in _wordBlocks) {
      final intersection = word.rect.intersect(normalized);
      if (intersection.isEmpty) continue;

      final wordArea = word.rect.width * word.rect.height;
      if (wordArea <= 0) continue;

      final overlapRatio =
          (intersection.width * intersection.height) / wordArea;

      final center = word.rect.center;
      if (overlapRatio >= 0.40 || normalized.contains(center)) {
        selected.add(word);
      }
    }

    if (selected.isEmpty) return '';

    selected.sort((a, b) {
      final rowDiff = (a.rect.top - b.rect.top);
      if (rowDiff.abs() > 0.01) return rowDiff < 0 ? -1 : 1;
      return a.rect.left.compareTo(b.rect.left);
    });

    final lines = <List<_WordBlock>>[];
    for (final word in selected) {
      if (lines.isEmpty ||
          (word.rect.top - lines.last.first.rect.top).abs() > 0.01) {
        lines.add([word]);
      } else {
        lines.last.add(word);
      }
    }

    return lines.map((line) => line.map((w) => w.text).join(' ')).join('\n');
  }

  Future<void> _confirm(Size widgetSize) async {
    setState(() => _isProcessing = true);

    String text;
    if (_hasSelection && _selectionRect != null) {
      text = _extractSelectedText(_selectionRect!, widgetSize);
      if (text.trim().isEmpty) {
        text = _allBlockTexts.join('\n\n');
      }
    } else {
      text = _allBlockTexts.join('\n\n');
    }

    final fileName = 'Camera_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await HistoryStore.add(fileName, widget.imageFile.path);

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (widget.backToHome) {
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
    } else {
      Navigator.of(context).pop(text.isEmpty ? null : text);
    }
  }

  void _goBack() {
    if (widget.backToHome) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      Navigator.of(context).pop();
    }
  }

  Widget _modeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _modeBtn(_Mode.select, Icons.crop, 'Select'),
          _modeBtn(_Mode.zoom, Icons.zoom_in, 'Zoom'),
        ],
      ),
    );
  }

  Widget _modeBtn(_Mode mode, IconData icon, String label) {
    final active = _mode == mode;
    return GestureDetector(
      onTap: () => setState(() => _mode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1D9E75) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          children: [
            Icon(icon, size: 25,
                color: active ? Colors.white : Colors.white60),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: active ? Colors.white : Colors.white60,
                    fontSize: 15)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: const Color(0xFF38616A),
          foregroundColor: Colors.white,
          title: const Text('Select region',
              style: TextStyle(fontWeight: FontWeight.w600)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _goBack,
          ),
        ),
        body: !_imageLoaded
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text('Scanning image...',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 16)),
                  ],
                ),
              )
            : Column(
                children: [
                  Container(
                    width: double.infinity,
                    color: Colors.white.withOpacity(0.08),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Text(
                      _mode == _Mode.zoom
                          ? '⊕  Zoom mode — pinch or drag to zoom'
                          : _hasSelection
                              ? 'Drag corners to resize · drag inside to move'
                              : '✦  Select mode — drag to draw a selection',
                      style: TextStyle(
                        color: _mode == _Mode.zoom
                            ? const Color(0xFF5DCAA5)
                            : Colors.white70,
                        fontSize: 17,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final widgetSize = Size(
                            constraints.maxWidth, constraints.maxHeight);

                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            InteractiveViewer(
                              transformationController:
                                  _transformationController,
                              panEnabled: _mode == _Mode.zoom,
                              scaleEnabled: _mode == _Mode.zoom,
                              minScale: 1.0,
                              maxScale: 6.0,
                              child: Image.memory(
                                _imageBytes!,
                                fit: BoxFit.contain,
                                width: constraints.maxWidth,
                                height: constraints.maxHeight,
                              ),
                            ),
                            if (_mode == _Mode.select)
                              GestureDetector(
                                onPanStart: _onPanStart,
                                onPanUpdate: _onPanUpdate,
                                onPanEnd: _onPanEnd,
                                child: CustomPaint(
                                  painter: _OverlayPainter(
                                    selectionRect: _selectionRect,
                                    confirmed: _hasSelection,
                                    imageRect: _getImageRect(widgetSize),
                                  ),
                                  child: const SizedBox.expand(),
                                ),
                              )
                            else
                              IgnorePointer(
                                child: CustomPaint(
                                  painter: _OverlayPainter(
                                    selectionRect: _selectionRect,
                                    confirmed: _hasSelection,
                                    imageRect: _getImageRect(widgetSize),
                                  ),
                                  child: const SizedBox.expand(),
                                ),
                              ),
                            Positioned(
                              top: 12,
                              right: 12,
                              child: GestureDetector(
                                onTap: _resetZoom,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.55),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.zoom_out_map,
                                          color: Colors.white70, size: 16),
                                      SizedBox(width: 4),
                                      Text('Reset zoom',
                                          style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 15)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 16,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: _buildExtractButton(widgetSize),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _modeToggle(),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: _isProcessing ? null : () => _confirm(widgetSize),
          icon: _isProcessing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.text_snippet, size: 22),
          label: Text(
            _isProcessing
                ? 'Processing...'
                : _hasSelection
                    ? 'Extract region'
                    : 'Extract all',
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF38616A),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
                horizontal: 28, vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      color: const Color(0xFF1A1A1A),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton.icon(
            onPressed: _resetSelection,
            icon: const Icon(Icons.clear, color: Colors.white70),
            label: const Text('Reset selection',
                style: TextStyle(color: Colors.white70, fontSize: 15)),
          ),
        ],
      ),
    );
  }
}

enum _Handle { topLeft, topRight, bottomLeft, bottomRight, move }

class _OverlayPainter extends CustomPainter {
  final Rect? selectionRect;
  final bool confirmed;
  final Rect imageRect;

  const _OverlayPainter({
    required this.selectionRect,
    required this.confirmed,
    required this.imageRect,
  });

  @override
  void paint(Canvas canvas, Size size) {
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
        ..color = confirmed ? const Color(0xFF1D9E75) : Colors.white
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
      old.selectionRect != selectionRect ||
      old.confirmed != confirmed ||
      old.imageRect != imageRect;
}