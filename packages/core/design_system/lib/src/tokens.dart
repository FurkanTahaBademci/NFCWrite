import 'package:flutter/material.dart';

/// Bosluk olcegi — 4'un katlari.
///
/// Elle `EdgeInsets.all(13)` yazma; bu olcegi kullan ki ekranlar arasi
/// ritim tutarli kalsin.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

/// Kose yaricaplari.
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double sheet = 28;
  static const double pill = 999;

  static const BorderRadius card = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius button = BorderRadius.all(Radius.circular(md));
  static const BorderRadius bottomSheet = BorderRadius.vertical(
    top: Radius.circular(sheet),
  );
}

/// Bir islemin ya da durumun risk seviyesi — renk ve ikon buradan gelir.
///
/// **Renk tek basina anlam tasimaz**; her zaman ikon ve metinle birlikte
/// kullan (erisilebilirlik).
enum RiskLevel {
  /// Etiketi degistirmez.
  safe,

  /// Icerigi degistirir, geri yazilabilir.
  caution,

  /// Yapilandirmayi degistirir.
  warning,

  /// Geri alinamaz.
  danger;

  /// Bu seviyenin ikonu.
  IconData get icon => switch (this) {
    RiskLevel.safe => Icons.check_circle_outline,
    RiskLevel.caution => Icons.info_outline,
    RiskLevel.warning => Icons.warning_amber_outlined,
    RiskLevel.danger => Icons.dangerous_outlined,
  };
}

/// Uygulamaya ozel renkler.
///
/// Material 3 renk semasinda karsiligi olmayan, anlam tasiyan renkler.
abstract final class AppColors {
  /// Dinamik renk yoksa kullanilacak tohum.
  static const Color seed = Color(0xFF2563EB);

  static const Color safe = Color(0xFF16A34A);
  static const Color caution = Color(0xFF0EA5E9);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFDC2626);

  static const Color safeDark = Color(0xFF4ADE80);
  static const Color cautionDark = Color(0xFF38BDF8);
  static const Color warningDark = Color(0xFFFBBF24);
  static const Color dangerDark = Color(0xFFF87171);

  /// Risk seviyesinin temaya uygun rengi.
  static Color forRisk(RiskLevel risk, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return switch (risk) {
      RiskLevel.safe => isDark ? safeDark : safe,
      RiskLevel.caution => isDark ? cautionDark : caution,
      RiskLevel.warning => isDark ? warningDark : warning,
      RiskLevel.danger => isDark ? dangerDark : danger,
    };
  }
}

/// Yazi tipi olcegi.
abstract final class AppTypography {
  /// Hex dokumu, UID ve ham veri icin tek aralikli (monospace) yazi tipi.
  ///
  /// Platform yazi tipini kullanir; paket boyutunu buyutmemek icin
  /// disaridan font indirilmez.
  static const List<String> monospaceFamilies = [
    'monospace',
    'Roboto Mono',
    'Courier New',
  ];

  /// Hex/dump alanlari icin stil.
  static TextStyle monospace(BuildContext context, {double? fontSize}) =>
      TextStyle(
        fontFamily: monospaceFamilies.first,
        fontFamilyFallback: monospaceFamilies.sublist(1),
        fontSize: fontSize ?? 13,
        height: 1.5,
        letterSpacing: 0.5,
        color: Theme.of(context).colorScheme.onSurface,
      );
}
