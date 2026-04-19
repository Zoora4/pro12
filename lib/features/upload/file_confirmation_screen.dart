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
          title: const Text('Confirm File',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: const Color(0xFF2E4D52),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 32),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 12),
                        Icon(
                          _isImage
                              ? Icons.image
                              : Icons.insert_drive_file,
                          size: 72,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'File Selected Successfully',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 20),

                        // File info card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white30),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('📄 File Name:',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              Text(fileName,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2),
                              const SizedBox(height: 14),
                              const Text('📦 File Type:',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              Text(fileExtension,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 14)),
                            ],
                          ),
                        ),

                        // Image preview
                        if (_isImage) ...[
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: constraints.maxHeight * 0.25,
                              ),
                              child: Image.file(
                                file,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ],

                        const Spacer(),
                        const SizedBox(height: 24),

                        // Confirm button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _onConfirm(context),
                            icon: const Icon(Icons.check_circle_outline,
                                size: 24),
                            label: const Text('Confirm Upload',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF38616A),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 32, vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        TextButton.icon(
                          onPressed: () =>
                              UploadController.pickFile(context),
                          icon: const Icon(Icons.refresh,
                              color: Colors.white, size: 22),
                          label: const Text(
                            'Select Other File',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _onConfirm(BuildContext context) async {
    await HistoryStore.add(fileName, file.path);
    if (!context.mounted) return;

    if (_isImage) {
      // ── FIX: await the region screen and carry the selected text forward ──
      final selectedText = await Navigator.push<String?>(
        context,
        MaterialPageRoute(
          builder: (_) => ImageRegionScreen(
            imageFile: file,
            backToHome: false,
          ),
        ),
      );

      // ImageRegionScreen already pushes AnalyzeScreen internally when
      // backToHome == false is NOT set — but our ImageRegionScreen with
      // backToHome:false pops with the text string.  Push AnalyzeScreen here.
      if (!context.mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AnalyzeScreen(
            filePath: file.path,
            overrideText: selectedText,
            backToHome: true,
            sourceImageFile: file,
          ),
        ),
      );
    } else {
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
  }
}