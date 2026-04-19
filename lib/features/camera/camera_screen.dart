import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/history/history_store.dart';
import 'image_region_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  @override
  void initState() {
    super.initState();
    _openCamera();
  }

  Future<void> _openCamera() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 95,
    );

    if (picked != null && mounted) {
      final file = File(picked.path);
      final fileName = 'Camera_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // ── Register in history immediately after capture ──────
      // This way the file appears in History as soon as the photo
      // is taken, not only after the user taps "Extract".
      await HistoryStore.add(fileName, file.path);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ImageRegionScreen(
            imageFile: file,
            backToHome: true,
          ),
        ),
      );
    } else {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}