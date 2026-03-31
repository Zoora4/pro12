import 'dart:io';
import 'package:flutter/material.dart';

import '../core/history/history_store.dart';
import '../features/analyze/analyze_screen.dart';
import '../features/camera/image_region_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  Widget build(BuildContext context) {
    final history = HistoryStore.recentFiles;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 153, 181, 187),
        foregroundColor: Colors.black,
        title: const Text(
          "Recent Files",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: history.isEmpty
            ? const Center(
                child: Text(
                  "No history yet",
                  style: TextStyle(fontSize: 16),
                ),
              )
            : ListView.separated(
                itemCount: history.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: 15),
                itemBuilder: (context, index) {
                  final item = history[index];
                  final type = item['type'] ?? 'file';
                  final name = item['name'] ?? 'Unknown File';
                  final path = item['path'];

                  return SizedBox(
                    height: 120,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (path == null) return;

                        await HistoryStore.add(name, path);

                        final ext =
                            path.split('.').last.toLowerCase();
                        final isImage = ['jpg', 'jpeg', 'png']
                            .contains(ext);
                        final fileExists =
                            await File(path).exists();

                        if (!context.mounted) return;

                        if (!fileExists) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'File no longer exists on device'),
                            ),
                          );
                          return;
                        }

                        if (isImage) {
                          // Images → region screen so user
                          // can re-select region
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ImageRegionScreen(
                                imageFile: File(path),
                                backToHome: true,
                              ),
                            ),
                          );
                        } else {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AnalyzeScreen(
                                filePath: path,
                                backToHome: true,
                              ),
                            ),
                          );
                        }

                        setState(() {});
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF38616A),
                        elevation: 7,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getIcon(type),
                            size: 40,
                            color: const Color(0xFF38616A),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  _formatTime(item['time']),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  IconData _getIcon(String type) {
    switch (type.toLowerCase()) {
      case 'image':
        return Icons.image;
      case 'camera':
        return Icons.camera_alt;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatTime(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw);
      final year = dt.year.toString();
      final month = dt.month.toString().padLeft(2, '0');
      final day = dt.day.toString().padLeft(2, '0');
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return "$year-$month-$day $hour:$minute";
    } catch (e) {
      return raw;
    }
  }
}