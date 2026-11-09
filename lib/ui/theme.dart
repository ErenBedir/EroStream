import 'package:flutter/material.dart';

/// Design tokens. Warm dark grey instead of pure black, soft text contrast,
/// a single accent. Everything else derives from these values.
abstract final class Palette {
  static const bg = Color(0xFF141312);
  static const surface = Color(0xFF1C1B19);
  static const surfaceHigh = Color(0xFF252320);
  static const line = Color(0x1AFFFFFF);
  static const text = Color(0xFFECE7E1);
  static const textDim = Color(0xFFA29C94);
  static const textFaint = Color(0xFF6E6A64);
  static const accent = Color(0xFFE3A55B);
  static const onAccent = Color(0xFF1E1407);
  static const danger = Color(0xFFE07A6B);
}

abstract final class Space {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;
}

abstract final class Radii {
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
}

abstract final class Motion {
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 200);
  static const curve = Curves.easeOutCubic;
}

/// Width breakpoints. TV and desktop use the wide layout with a side rail.
abstract final class Breakpoints {
  static const wide = 840.0;
  static bool isWide(BuildContext c) => MediaQuery.sizeOf(c).width >= wide;
}

ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
    surface: Palette.bg,
    surfaceContainerLowest: Palette.bg,
    surfaceContainerLow: Palette.surface,
    surfaceContainer: Palette.surface,
    surfaceContainerHigh: Palette.surfaceHigh,
    surfaceContainerHighest: Palette.surfaceHigh,
    onSurface: Palette.text,
    onSurfaceVariant: Palette.textDim,
    primary: Palette.accent,
    onPrimary: Palette.onAccent,
    secondary: Palette.accent,
    onSecondary: Palette.onAccent,
    outline: Palette.line,
    outlineVariant: Palette.line,
    error: Palette.danger,
  );

  const text = TextTheme(
    displaySmall: TextStyle(fontSize: 32, fontWeight: FontWeight.w600, height: 1.15, letterSpacing: -0.5),
    headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.25, letterSpacing: -0.2),
    titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.3),
    titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.35),
    bodyLarge: TextStyle(fontSize: 15, height: 1.5),
    bodyMedium: TextStyle(fontSize: 14, height: 1.5),
    bodySmall: TextStyle(fontSize: 12.5, height: 1.45, color: Palette.textDim),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.2),
  );

  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.m));
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: Brightness.dark);

  return base.copyWith(
    scaffoldBackgroundColor: Palette.bg,
    textTheme: base.textTheme.merge(text).apply(bodyColor: Palette.text, displayColor: Palette.text),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: Colors.white.withValues(alpha: 0.04),
    focusColor: Palette.accent.withValues(alpha: 0.18),
    dividerTheme: const DividerThemeData(color: Palette.line, thickness: 1, space: 1),
    appBarTheme: const AppBarTheme(
      backgroundColor: Palette.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Palette.text),
    ),
    cardTheme: CardThemeData(
      color: Palette.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: shape,
    ),
    listTileTheme: ListTileThemeData(
      shape: shape,
      iconColor: Palette.textDim,
      subtitleTextStyle: text.bodySmall,
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.l),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Palette.surface,
      hintStyle: const TextStyle(color: Palette.textFaint),
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.m), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.m),
        borderSide: const BorderSide(color: Palette.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.m),
        borderSide: const BorderSide(color: Palette.accent, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: Space.xl),
        shape: shape,
        textStyle: text.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: Space.xl),
        foregroundColor: Palette.text,
        side: const BorderSide(color: Palette.line),
        shape: shape,
        textStyle: text.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: Palette.accent, shape: shape, textStyle: text.labelLarge),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        side: const BorderSide(color: Palette.line),
        selectedBackgroundColor: Palette.accent.withValues(alpha: 0.16),
        selectedForegroundColor: Palette.accent,
        foregroundColor: Palette.textDim,
      ),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: Palette.bg,
      indicatorColor: Color(0x29E3A55B),
      selectedIconTheme: IconThemeData(color: Palette.accent),
      unselectedIconTheme: IconThemeData(color: Palette.textDim),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Palette.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Palette.accent.withValues(alpha: 0.16),
      height: 64,
      labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
    ),
    dialogTheme: DialogThemeData(backgroundColor: Palette.surfaceHigh, shape: shape),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Palette.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Palette.surfaceHigh,
      contentTextStyle: TextStyle(color: Palette.text),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: Palette.accent),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
    }),
  );
}
