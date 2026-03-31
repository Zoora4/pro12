import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../core/history/history_store.dart';

class ImageCropScreen extends StatefulWidget {
  final File imageFile;
  const ImageCropScreen({super.key, required this.imageFile});

  @override
  State<ImageCropScreen> createState() => _ImageCropScreenState();
}

class _ImageCropScreenState extends State<ImageCropScreen> {
  final _cropController = CropController();
  late Uint8List _imageBytes;
  bool _imageLoaded = false;

  bool _isProcessing = false;
  bool _isCropping = false;
  bool _cropDone = false;
  Uint8List? _croppedBytes;
  List<_TextBlock> _textBlocks = [];
  double _confidence = 1.0;
  bool _showRegions = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    _imageBytes = await widget.imageFile.readAsBytes();
    if (mounted) setState(() => _imageLoaded = true);
  }

  // ─── CROP DONE — uses exact API from official sample ─────────
  void _onCropped(result) {
    switch (result) {
      case CropSuccess(:final croppedImage):
        setState(() {
          _croppedBytes = croppedImage;
          _cropDone = true;
          _isCropping = false;
          _isProcessing = true;
        });
        _runOcr(croppedImage);
      case CropFailure(:final cause):
        setState(() => _isCropping = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Crop failed: $cause')),
          );
        }
    }
  }

  // ─── RUN OCR ON CROPPED BYTES ────────────────────────────────
  Future<void> _runOcr(Uint8List bytes) async {
    final tempPath =
        '${widget.imageFile.parent.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final tempFile = File(tempPath);
    await tempFile.writeAsBytes(bytes);

    final input = InputImage.fromFile(tempFile);
    final recognizer = TextRecognizer();
    final result = await recognizer.processImage(input);
    await recognizer.close();

    final blocks = result.blocks;
    double totalConf = 0;
    int count = 0;
    final parsedBlocks = <_TextBlock>[];

    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final imgW = frame.image.width.toDouble();
    final imgH = frame.image.height.toDouble();

    for (final block in blocks) {
      final conf = block.recognizedLanguages.isNotEmpty ? 0.9 : 0.6;
      totalConf += conf;
      count++;
      final r = block.boundingBox;
      parsedBlocks.add(_TextBlock(
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
        _textBlocks = parsedBlocks;
        _confidence = count > 0 ? totalConf / count : 0.5;
        _isProcessing = false;
        _showRegions = true;
      });
    }
  }

  // ─── CONFIRM → ANALYZE ───────────────────────────────────────
  Future<void> _confirm() async {
    if (_croppedBytes == null) return;

    final path =
        '${widget.imageFile.parent.path}/scan_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(path).writeAsBytes(_croppedBytes!);

    final fileName = 'Camera_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await HistoryStore.add(fileName, path);

    if (mounted) {
      Navigator.pop(context, path);
    }
  }

  void _retake() => Navigator.pop(context);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF38616A),
        foregroundColor: Colors.white,
        title: Text(
          _cropDone ? 'Confirm scan' : 'Crop image',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _retake,
        ),
        actions: _cropDone
            ? [
                IconButton(
                  icon: const Icon(Icons.grid_on),
                  tooltip: 'Toggle text regions',
                  onPressed: () =>
                      setState(() => _showRegions = !_showRegions),
                ),
              ]
            : null,
      ),
      body: !_imageLoaded
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white))
          : _cropDone
              ? _buildConfirmView()
              : _buildCropView(),
    );
  }

  // ─── CROP VIEW ────────────────────────────────────────────────
  Widget _buildCropView() {
    return Column(
      children: [
        Expanded(
          child: Crop(
            image: _imageBytes,
            controller: _cropController,
            onCropped: _onCropped,
            interactive: true,
            baseColor: Colors.black,
            maskColor: Colors.black.withOpacity(0.5),
            radius: 8,
            initialRectBuilder: InitialRectBuilder.withBuilder(
              (viewportRect, imageRect) => Rect.fromLTRB(
                viewportRect.left + 24,
                viewportRect.top + 32,
                viewportRect.right - 24,
                viewportRect.bottom - 32,
              ),
            ),
          ),
        ),
        _buildCropToolbar(),
      ],
    );
  }

  Widget _buildCropToolbar() {
    return Container(
      color: const Color(0xFF1A1A1A),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          TextButton.icon(
            onPressed: _retake,
            icon: const Icon(Icons.refresh, color: Colors.white70),
            label: const Text('Retake',
                style: TextStyle(color: Colors.white70, fontSize: 16)),
          ),
          ElevatedButton.icon(
            onPressed: _isCropping
                ? null
                : () {
                    setState(() => _isCropping = true);
                    _cropController.crop();
                  },
            icon: _isCropping
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.crop, size: 22),
            label: Text(
              _isCropping ? 'Cropping...' : 'Crop',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF38616A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── CONFIRM VIEW ─────────────────────────────────────────────
  Widget _buildConfirmView() {
    if (_isProcessing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text('Scanning text...',
                style: TextStyle(color: Colors.white70, fontSize: 16)),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildConfidenceBanner(),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.memory(_croppedBytes!, fit: BoxFit.contain),
              if (_showRegions && _textBlocks.isNotEmpty)
                CustomPaint(painter: _RegionPainter(_textBlocks)),
            ],
          ),
        ),
        _buildConfirmToolbar(),
      ],
    );
  }

  Widget _buildConfidenceBanner() {
    final isGood = _confidence >= 0.75;
    final color =
        isGood ? const Color(0xFF1D9E75) : const Color(0xFFD85A30);
    final icon =
        isGood ? Icons.check_circle : Icons.warning_amber_rounded;
    final label = isGood
        ? 'Good scan quality'
        : 'Low scan quality — consider retaking';

    return Container(
      width: double.infinity,
      color: color.withOpacity(0.15),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
          ),
          Text(
            '${(_confidence * 100).round()}%',
            style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmToolbar() {
    return Container(
      color: const Color(0xFF1A1A1A),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          TextButton.icon(
            onPressed: () => setState(() {
              _cropDone = false;
              _croppedBytes = null;
              _textBlocks = [];
            }),
            icon: const Icon(Icons.crop, color: Colors.white70),
            label: const Text('Re-crop',
                style: TextStyle(color: Colors.white70, fontSize: 16)),
          ),
          TextButton.icon(
            onPressed: _retake,
            icon: const Icon(Icons.refresh, color: Colors.white70),
            label: const Text('Retake',
                style: TextStyle(color: Colors.white70, fontSize: 16)),
          ),
          ElevatedButton.icon(
            onPressed: _confirm,
            icon: const Icon(Icons.check, size: 22),
            label: const Text('Use this',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
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
      ),
    );
  }
}

// ─── TEXT BLOCK MODEL ─────────────────────────────────────────
class _TextBlock {
  final String text;
  final Rect rect;
  const _TextBlock({required this.text, required this.rect});
}

// ─── REGION PAINTER ───────────────────────────────────────────
class _RegionPainter extends CustomPainter {
  final List<_TextBlock> blocks;
  const _RegionPainter(this.blocks);

  @override
  void paint(Canvas canvas, Size size) {
    final boxPaint = Paint()
      ..color = const Color(0xFF1D9E75).withOpacity(0.35)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = const Color(0xFF1D9E75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final block in blocks) {
      final rect = Rect.fromLTRB(
        block.rect.left * size.width,
        block.rect.top * size.height,
        block.rect.right * size.width,
        block.rect.bottom * size.height,
      );
      canvas.drawRect(rect, boxPaint);
      canvas.drawRect(rect, borderPaint);
    }
  }

  @override
  bool shouldRepaint(_RegionPainter old) => old.blocks != blocks;
}