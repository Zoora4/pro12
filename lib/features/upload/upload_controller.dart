import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import 'file_confirmation_screen.dart';

class UploadController {
  static Future<void> pickFile(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt',
          'jpg', 'jpeg', 'png', 'gif',
        ],
      );

      if (result == null) {
        if (context.mounted) {
          Navigator.of(context).pop(); // Pop current screen
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop(); // Pop to home
          }
        }
        return;
      }

      if (result.files.single.path == null) {
        if (context.mounted) {
          Navigator.of(context).pop(); // Pop current screen
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop(); // Pop to home
          }
        }
        return;
      }

      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;

      if (!context.mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FileConfirmationScreen(
            file: file,
            fileName: fileName,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }
}