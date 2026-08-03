import 'dart:developer' as developer;

/// Kayit seviyesi.
enum LogLevel {
  debug(500, 'DEBUG'),
  info(800, 'INFO'),
  warning(900, 'WARN'),
  error(1000, 'ERROR');

  const LogLevel(this.value, this.label);

  /// `dart:developer` seviye degeri.
  final int value;
  final String label;
}

/// Basit, bagimliliksiz kayit tutucu.
///
/// `print` kullanma — bu sinifi kullan. Uretimde [minimumLevel] yukseltilerek
/// ayrintili kayitlar kapatilir.
///
/// NFC komut trafigini kaydederken **sifreleri kaydetme.**
final class AppLogger {
  const AppLogger(this.name);

  /// Kayit kaynagi, genelde paket ya da sinif adi.
  final String name;

  /// Bu seviyenin altindaki kayitlar yok sayilir.
  static LogLevel minimumLevel = LogLevel.debug;

  /// Kayit tutma tamamen kapali mi?
  static bool enabled = true;

  void debug(String message) => _log(LogLevel.debug, message);

  void info(String message) => _log(LogLevel.info, message);

  void warning(String message, [Object? error]) =>
      _log(LogLevel.warning, message, error);

  void error(String message, [Object? error, StackTrace? stackTrace]) =>
      _log(LogLevel.error, message, error, stackTrace);

  void _log(
    LogLevel level,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    if (!enabled || level.value < minimumLevel.value) return;
    developer.log(
      message,
      name: name,
      level: level.value,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
