import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/history/history_store.dart';
import '../analyze/analyze_screen.dart';

class CameraController {
  final ImagePicker _picker = ImagePicker();

  File? imageFile;
  bool isLoading = true;

  Future<void> openCamera(BuildContext context) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
      );

      if (pickedFile == null) {
        isLoading = false;
        return;
      }

      imageFile = File(pickedFile.path);

      final fileName =
          "Camera_${DateTime.now().millisecondsSinceEpoch}.jpg";

      await HistoryStore.add(fileName, imageFile!.path);

      if (!context.mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              AnalyzeScreen(filePath: imageFile!.path),
        ),
      );
    } catch (e) {
      debugPrint("Camera error: $e");
      isLoading = false;
    }
  }
}