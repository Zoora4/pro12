import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

class HistoryStore {
  static final List<Map<String, String>> recentFiles = [];
  static const String _prefsKey = 'recentFiles';

  static String _normalizePath(String path) {
    if (path.trim().isEmpty) return '';

    var normalized = File(path).absolute.path.replaceAll('\\', '/');
    if (Platform.isWindows) {
      normalized = normalized.toLowerCase();
    }
    return normalized;
  }

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_prefsKey);
    if (encoded == null || encoded.isEmpty) return;

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is List) {
        recentFiles.clear();
        for (final item in decoded) {
          if (item is Map) {
            final map = <String, String>{};
            item.forEach((k, v) => map[k.toString()] = v.toString());
            final normalizedPath = _normalizePath(map['path'] ?? '');
            if (normalizedPath.isEmpty) continue;
            map['path'] = normalizedPath;
            recentFiles.add(map);
          }
        }
        recentFiles.sort((a, b) {
          final aTime = DateTime.tryParse(a['time'] ?? '') ?? DateTime(1970);
          final bTime = DateTime.tryParse(b['time'] ?? '') ?? DateTime(1970);
          return bTime.compareTo(aTime);
        });
      }
    } catch (e) {
      recentFiles.clear();
    }
  }

  static Future<void> add(String name, String path) async {
    final normalizedPath = _normalizePath(path);
    if (normalizedPath.isEmpty) return;

    final now = DateTime.now().toIso8601String();
    final ext = normalizedPath.split('.').last.toLowerCase();
    final type = ['jpg', 'jpeg', 'png'].contains(ext)
        ? (name.toLowerCase().contains('camera') ? 'camera' : 'image')
        : 'file';

    final index = recentFiles.indexWhere(
      (e) => (e['path'] ?? '') == normalizedPath,
    );

    if (index != -1) {
      final item = recentFiles.removeAt(index);
      item['name'] = name;
      item['path'] = normalizedPath;
      item['time'] = now;
      item['type'] = type;
      recentFiles.insert(0, item);
    } else {
      recentFiles.insert(0, {
        'name': name,
        'path': normalizedPath,
        'time': now,
        'type': type,
      });
    }

    if (recentFiles.length > 20) {
      recentFiles.removeRange(20, recentFiles.length);
    }

    await _save();
  }

  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(recentFiles));
  }

  static Future<void> clear() async {
    recentFiles.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}
