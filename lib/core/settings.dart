import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';

/// User settings. Empty strings / zero mean "use the build default".
class Settings extends ChangeNotifier {
  Settings._(this._p);

  static Future<Settings> load() async => Settings._(await SharedPreferences.getInstance());

  final SharedPreferences _p;

  static const _kLocale = 'locale';
  static const _kTmdb = 'tmdb_key';
  static const _kTmdbLang = 'tmdb_language';
  static const _kApiId = 'tg_api_id';
  static const _kApiHash = 'tg_api_hash';
  static const _kCacheMb = 'cache_limit_mb';

  /// '' = follow the system language.
  String get localeCode => _p.getString(_kLocale) ?? '';
  Locale? get locale => localeCode.isEmpty ? null : Locale(localeCode);
  set localeCode(String v) => _set(_kLocale, v);

  String get tmdbKeyOverride => _p.getString(_kTmdb) ?? '';
  set tmdbKeyOverride(String v) => _set(_kTmdb, v.trim());
  String get tmdbKey => tmdbKeyOverride.isNotEmpty ? tmdbKeyOverride : AppConfig.tmdbKey;

  /// Metadata language, e.g. `tr-TR`. '' = derive from the UI language.
  String get tmdbLanguage => _p.getString(_kTmdbLang) ?? '';
  set tmdbLanguage(String v) => _set(_kTmdbLang, v.trim());

  int get apiIdOverride => _p.getInt(_kApiId) ?? 0;
  String get apiHashOverride => _p.getString(_kApiHash) ?? '';
  int get apiId => apiIdOverride != 0 ? apiIdOverride : AppConfig.telegramApiId;
  String get apiHash => apiHashOverride.isNotEmpty ? apiHashOverride : AppConfig.telegramApiHash;
  bool get hasTelegramCredentials => apiId != 0 && apiHash.isNotEmpty;

  Future<void> setTelegramCredentials(int id, String hash) async {
    await _p.setInt(_kApiId, id);
    await _p.setString(_kApiHash, hash.trim());
    notifyListeners();
  }

  int get cacheLimitMb => _p.getInt(_kCacheMb) ?? 2048;
  set cacheLimitMb(int v) {
    _p.setInt(_kCacheMb, v);
    notifyListeners();
  }

  /// Raw access for modules that keep small JSON blobs (libraries, sources).
  String? readBlob(String key) => _p.getString(key);
  Future<void> writeBlob(String key, String value) => _p.setString(key, value);

  void _set(String k, String v) {
    _p.setString(k, v);
    notifyListeners();
  }
}
