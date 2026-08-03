import 'package:flutter/services.dart';
import 'package:nfc_core/nfc_core.dart';

/// Platform hatalarini [NfcFailure] tiplerine cevirir.
///
/// Android NFC API'si cogu hatayi `IOException` ya da `TagLostException`
/// olarak firlatir; bunlar Flutter tarafina [PlatformException] icinde
/// mesaj metni olarak gelir. Metin esleme kirilgan oldugu icin burada
/// tek yerde toplanir.
abstract final class ErrorMapper {
  /// Etiketin alandan ciktigini belirten platform mesaji kaliplari.
  static const List<String> _tagLostPatterns = [
    'tag was lost',
    'taglostexception',
    'tag is not connected',
    'out of date',
  ];

  /// Yazma korumasi kaliplari.
  static const List<String> _readOnlyPatterns = [
    'read-only',
    'read only',
    'not writable',
    'cannot write',
  ];

  /// Yer yetmedi kaliplari.
  static const List<String> _spacePatterns = [
    'too large',
    'not enough space',
    'exceeds',
  ];

  /// Bir hatayi [NfcFailure] tipine cevirir.
  static NfcFailure map(Object error, [StackTrace? stackTrace]) {
    if (error is NfcFailure) return error;

    final message = _messageOf(error).toLowerCase();

    if (_matchesAny(message, _tagLostPatterns)) {
      return const TagLost();
    }
    if (_matchesAny(message, _readOnlyPatterns)) {
      return const TagReadOnly();
    }
    if (_matchesAny(message, _spacePatterns)) {
      // Platform kesin sayilari vermiyor; ayrintiyi ust katman doldurur.
      return const InsufficientSpace(needed: -1, available: -1);
    }
    if (message.contains('format')) {
      return MalformedData(_messageOf(error));
    }

    return TransportError(
      _messageOf(error),
      cause: error,
      stackTrace: stackTrace,
    );
  }

  static bool _matchesAny(String haystack, List<String> needles) {
    for (final needle in needles) {
      if (haystack.contains(needle)) return true;
    }
    return false;
  }

  static String _messageOf(Object error) => switch (error) {
    PlatformException(:final message, :final code) =>
      message ?? 'PlatformException($code)',
    MissingPluginException() => 'Platform eklentisi bulunamadi',
    _ => error.toString(),
  };
}
