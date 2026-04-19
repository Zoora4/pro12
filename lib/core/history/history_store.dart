import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryStore extends ChangeNotifier {
  // ── Singleton ─────────────────────────────────────────────
  static final HistoryStore _instance = HistoryStore._internal();
  factory HistoryStore() => _instance;
  HistoryStore._internal();

  static HistoryStore get instance => _instance;

  // ── Data ──────────────────────────────────────────────────
  final List<Map<String, String>> _recentFiles = [];
  static const String _prefsKey = 'recentFiles';

  List<Map<String, String>> get recentFiles =>
      List.unmodifiable(_recentFiles);

  // ── Init ──────────────────────────────────────────────────
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_prefsKey);
    if (encoded == null || encoded.isEmpty) return;

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is List) {
        _instance._recentFiles.clear();
        for (final item in decoded) {
          if (item is Map) {
            final map = <String, String>{};
            item.forEach((k, v) => map[k.toString()] = v.toString());
            final raw = map['path'] ?? '';
            if (raw.isEmpty) continue;
            // Store as-is; normalize only at comparison time
            map['path'] = raw;
            _instance._recentFiles.add(map);
          }
        }
        _instance._recentFiles.sort((a, b) {
          final aTime =
              DateTime.tryParse(a['time'] ?? '') ?? DateTime(1970);
          final bTime =
              DateTime.tryParse(b['time'] ?? '') ?? DateTime(1970);
          return bTime.compareTo(aTime);
        });
      }
    } catch (e) {
      _instance._recentFiles.clear();
    }
  }

  // ── Add ───────────────────────────────────────────────────
  static Future<void> add(String name, String path) async {
    final inst = _instance;
    final cleanPath = _cleanPath(path);
    if (cleanPath.isEmpty) return;

    final now = DateTime.now().toIso8601String();
    final ext = cleanPath.split('.').last.toLowerCase();
    final type = ['jpg', 'jpeg', 'png'].contains(ext)
        ? (name.toLowerCase().contains('camera') ? 'camera' : 'image')
        : 'file';

    // ── Find existing entry by filename match, not full path ──
    // Android can return the same file via different path roots
    // (/data/user/0/... vs /storage/emulated/0/...) so we compare
    // by the cleaned filename only as a fallback.
    final incomingFilename = _filename(cleanPath);

    final index = inst._recentFiles.indexWhere((e) {
      final storedPath = _cleanPath(e['path'] ?? '');
      if (storedPath == cleanPath) return true;
      // Fallback: same filename + same extension
      return _filename(storedPath) == incomingFilename &&
          storedPath.split('.').last.toLowerCase() == ext;
    });

    if (index != -1) {
      // Update in place, move to top
      final item = inst._recentFiles.removeAt(index);
      item['name'] = name;
      item['path'] = cleanPath; // update to latest resolved path
      item['time'] = now;
      item['type'] = type;
      inst._recentFiles.insert(0, item);
    } else {
      inst._recentFiles.insert(0, {
        'name': name,
        'path': cleanPath,
        'time': now,
        'type': type,
      });
    }

    if (inst._recentFiles.length > 20) {
      inst._recentFiles.removeRange(20, inst._recentFiles.length);
    }

    await inst._save();
    inst.notifyListeners();
  }

  // ── Clear ─────────────────────────────────────────────────
  static Future<void> clear() async {
    _instance._recentFiles.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    _instance.notifyListeners();
  }

  // ── Path helpers ──────────────────────────────────────────

  /// Collapses double slashes, strips trailing slash, lowercases on Windows.
  static String _cleanPath(String path) {
    if (path.trim().isEmpty) return '';
    var p = path.trim()
        .replaceAll('\\', '/')
        .replaceAll(RegExp(r'/+'), '/'); // collapse //
    if (p.endsWith('/')) p = p.substring(0, p.length - 1);
    if (Platform.isWindows) p = p.toLowerCase();
    return p;
  }

  /// Returns just the filename portion of a path.
  static String _filename(String cleanedPath) {
    final parts = cleanedPath.split('/');
    return parts.isNotEmpty ? parts.last : cleanedPath;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_recentFiles));
  }
}