import 'dart:io';
import 'package:flutter/material.dart';

import '../../core/history/history_store.dart';
import '../analyze/analyze_screen.dart';
import '../camera/image_region_screen.dart';
import 'upload_controller.dart';

class FileConfirmationScreen extends StatelessWidget {
  final File file;
  final String fileName;

  const FileConfirmationScreen({
    super.key,
    required this.file,
    required this.fileName,
  });

  bool get _isImage =>
      ['jpg', 'jpeg', 'png'].contains(fileName.split('.').last.toLowerCase());

  @override
  Widget build(BuildContext context) {
    final fileExtension = fileName.split('.').last.toUpperCase();

    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).popUntil((route) => route.isFirst);
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF38616A),
        appBar: AppBar(
          title: const Text(
            "Confirm File",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: const Color(0xFF2E4D52),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(
                  _isImage ? Icons.image : Icons.insert_drive_file,
                  size: 80,
                  color: Colors.white,
                ),
                const SizedBox(height: 20),
                const Text(
                  "File Selected Successfully",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 30),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white30),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "📄 File Name:",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(fileName,
                          style: const TextStyle(color: Colors.white)),
                      const SizedBox(height: 18),
                      const Text(
                        "📦 File Type:",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(fileExtension,
                          style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                ),

                // Show preview thumbnail for images
                if (_isImage) ...[
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      file,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],

                const SizedBox(height: 40),

                ElevatedButton.icon(
                  onPressed: () async {
                    await HistoryStore.add(fileName, file.path);

                    if (!context.mounted) return;

                    if (_isImage) {
                      // Images → region selection screen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ImageRegionScreen(
                            imageFile: file,
                            backToHome: false,
                          ),
                        ),
                      );
                    } else {
                      // PDF / DOCX → straight to analyze
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AnalyzeScreen(
                            filePath: file.path,
                            backToHome: true,
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.check_circle_outline, size: 28),
                  label: const Text(
                    "Confirm Upload",
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF38616A),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 45, vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                TextButton.icon(
                  onPressed: () => UploadController.pickFile(context),
                  icon: const Icon(Icons.refresh,
                      color: Colors.white, size: 26),
                  label: const Text(
                    "Select Other File",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}