import 'dart:io';
import 'package:flutter/material.dart';

import '../core/history/history_store.dart';
import '../features/analyze/analyze_screen.dart';
import '../features/camera/image_region_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ListenableBuilder rebuilds this widget whenever
    // HistoryStore.instance.notifyListeners() is called —
    // which happens inside HistoryStore.add() and HistoryStore.clear().
    return ListenableBuilder(
      listenable: HistoryStore.instance,
      builder: (context, _) {
        final history = HistoryStore.instance.recentFiles;

        return Scaffold(
          appBar: AppBar(
            centerTitle: true,
            backgroundColor: const Color.fromARGB(255, 153, 181, 187),
            foregroundColor: Colors.black,
            title: const Text(
              'Recent Files',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5),
            ),
          ),
          body: SafeArea(
            child: history.isEmpty
                ? const Center(
                    child: Text('No history yet',
                        style: TextStyle(fontSize: 16)))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: history.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = history[index];
                      final type = item['type'] ?? 'file';
                      final name = item['name'] ?? 'Unknown File';
                      final path = item['path'];

                      return _HistoryTile(
                        name: name,
                        type: type,
                        time: _formatTime(item['time']),
                        onTap: () async {
                          if (path == null) return;

                          // Re-stamp as most recent
                          await HistoryStore.add(name, path);

                          final ext =
                              path.split('.').last.toLowerCase();
                          final isImage =
                              ['jpg', 'jpeg', 'png'].contains(ext);
                          final fileExists =
                              await File(path).exists();

                          if (!context.mounted) return;

                          if (!fileExists) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'File no longer exists on device')),
                            );
                            return;
                          }

                          if (isImage) {
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
                          // No setState needed — ListenableBuilder handles it
                        },
                      );
                    },
                  ),
          ),
        );
      },
    );
  }

  String _formatTime(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.year}-${_p(dt.month)}-${_p(dt.day)}'
          ' ${_p(dt.hour)}:${_p(dt.minute)}';
    } catch (_) {
      return raw;
    }
  }

  String _p(int n) => n.toString().padLeft(2, '0');
}

// ─── History tile ─────────────────────────────────────────────
class _HistoryTile extends StatelessWidget {
  final String name;
  final String type;
  final String time;
  final VoidCallback onTap;

  const _HistoryTile({
    required this.name,
    required this.type,
    required this.time,
    required this.onTap,
  });

  IconData get _icon {
    switch (type.toLowerCase()) {
      case 'image':
        return Icons.image;
      case 'camera':
        return Icons.camera_alt;
      default:
        return Icons.insert_drive_file;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF38616A),
        elevation: 7,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15)),
      ),
      child: Row(
        children: [
          Icon(_icon, size: 50, color: const Color(0xFF38616A)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 15),
                Text(
                  time,
                  style: const TextStyle(
                      fontSize: 13, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_ios, size: 16),
        ],
      ),
    );
  }
}