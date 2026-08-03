import 'package:flutter/material.dart';

import 'tokens.dart';

/// Uygulama temalari.
abstract final class AppTheme {
  /// Acik tema.
  ///
  /// [dynamicScheme] Android 12+ dinamik rengi; yoksa tohum rengi kullanilir.
  static ThemeData light([ColorScheme? dynamicScheme]) =>
      _build(dynamicScheme ?? ColorScheme.fromSeed(seedColor: AppColors.seed));

  /// Koyu tema.
  static ThemeData dark([ColorScheme? dynamicScheme]) => _build(
    dynamicScheme ??
        ColorScheme.fromSeed(
          seedColor: AppColors.seed,
          brightness: Brightness.dark,
        ),
  );

  static ThemeData _build(ColorScheme scheme) {
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,

      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: scheme.surfaceTint,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 2,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),

      cardTheme: CardThemeData(
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // Dokunma hedefi en az 48dp — erisilebilirlik gereksinimi.
          minimumSize: const Size(64, 48),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.bottomSheet,
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.xl)),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: const OutlineInputBorder(
          borderRadius: AppRadius.button,
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadius.button,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.button,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
      ),

      listTileTheme: const ListTileThemeData(
        minVerticalPadding: AppSpacing.md,
        contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),

      chipTheme: ChipThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.sm)),
        ),
        side: BorderSide(color: scheme.outlineVariant),
        backgroundColor: scheme.surfaceContainerHighest,
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
      ),
    );
  }
}
