/// Build-time defaults, passed with `--dart-define-from-file=env.json`.
/// Every value can be overridden at runtime from Settings.
class AppConfig {
  static const appName = 'EroStream';
  static const version = String.fromEnvironment('APP_VERSION', defaultValue: '0.1.0-dev');

  static const telegramApiId = int.fromEnvironment('TG_API_ID');
  static const telegramApiHash = String.fromEnvironment('TG_API_HASH');

  /// TMDB v4 read access token or v3 API key.
  static const tmdbKey = String.fromEnvironment('TMDB_KEY');
}
