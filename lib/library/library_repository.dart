import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/settings.dart';
import 'models.dart';

/// Persists library definitions as one JSON blob. Small by design:
/// scanned items go to the item store, not here.
class LibraryRepository extends ChangeNotifier {
  LibraryRepository(this._settings) {
    _load();
  }

  static const _key = 'libraries_v1';
  final Settings _settings;
  List<MediaLibrary> _items = [];

  List<MediaLibrary> get libraries => List.unmodifiable(_items);

  /// Whether the first-run welcome screen was completed.
  bool get onboarded => _settings.readBlob('onboarded') == '1';

  Future<void> setOnboarded() async {
    await _settings.writeBlob('onboarded', '1');
    notifyListeners();
  }

  void _load() {
    final raw = _settings.readBlob(_key);
    if (raw == null || raw.isEmpty) return;
    try {
      _items = [
        for (final j in jsonDecode(raw) as List) MediaLibrary.fromJson((j as Map).cast<String, dynamic>()),
      ];
    } catch (e) {
      debugPrint('library config unreadable: $e');
    }
  }

  Future<void> _save() async {
    await _settings.writeBlob(_key, jsonEncode([for (final l in _items) l.toJson()]));
    notifyListeners();
  }

  static String newId() {
    final r = Random();
    return '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}${r.nextInt(1 << 20).toRadixString(36)}';
  }

  Future<void> upsert(MediaLibrary lib) async {
    final i = _items.indexWhere((l) => l.id == lib.id);
    if (i < 0) {
      _items = [..._items, lib];
    } else {
      _items = [..._items]..[i] = lib;
    }
    await _save();
  }

  Future<void> remove(String id) async {
    _items = _items.where((l) => l.id != id).toList();
    await _save();
  }

  /// Exported config, for backup or sharing a setup between devices.
  String exportJson() => const JsonEncoder.withIndent('  ').convert([for (final l in _items) l.toJson()]);
}
