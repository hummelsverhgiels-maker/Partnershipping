import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

const kBg = Color(0xFFFFF8F3);
const kBgTop = Color(0xFFFFEFE4);
const kAccent = Color(0xFFF2A88F);
const kAccentDeep = Color(0xFFE58E70);
const kAccentSoft = Color(0xFFFCE3D9);
const kInk = Color(0xFF4A3F3A);
const kInkSoft = Color(0xFF8C7F78);
const kLine = Color(0xFFF1E3DA);

/// Пастельные цвета для участников.
const kMemberColors = <int>[
  0xFFF7B7B7, // розовый
  0xFFFBC9A0, // персик
  0xFFF8E0A0, // масло
  0xFFB9E4B1, // мята
  0xFFA8DCD9, // бирюза
  0xFFAFCBFF, // небо
  0xFFD1B8F0, // лаванда
  0xFFF4B8DE, // сирень
];

/// Мягкая прокрутка с «пружинкой» на всех устройствах.
class SoftScrollBehavior extends MaterialScrollBehavior {
  const SoftScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.trackpad,
  };

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: kAccent,
    brightness: Brightness.light,
  ).copyWith(primary: kAccentDeep, surface: Colors.white, onSurface: kInk);

  const pill = StadiumBorder();
  const cupertino = CupertinoPageTransitionsBuilder();

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: Colors.white,
    splashColor: kAccent.withValues(alpha: 0.10),
    highlightColor: Colors.transparent,
    hoverColor: kAccent.withValues(alpha: 0.05),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: cupertino,
        TargetPlatform.iOS: cupertino,
        TargetPlatform.macOS: cupertino,
        TargetPlatform.windows: cupertino,
        TargetPlatform.linux: cupertino,
        TargetPlatform.fuchsia: cupertino,
      },
    ),
    textTheme: Typography.material2021().black.apply(
      bodyColor: kInk,
      displayColor: kInk,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: kInk,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleSpacing: 20,
      titleTextStyle: TextStyle(
        color: kInk,
        fontSize: 26,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 72,
      indicatorColor: kAccentSoft,
      indicatorShape: pill,
      iconTheme: WidgetStateProperty.resolveWith(
        (st) => IconThemeData(
          color: st.contains(WidgetState.selected) ? kAccentDeep : kInkSoft,
          size: 26,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (st) => TextStyle(
          fontSize: 11.5,
          fontWeight: st.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w600,
          color: st.contains(WidgetState.selected) ? kAccentDeep : kInkSoft,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 56),
        backgroundColor: kAccentDeep,
        foregroundColor: Colors.white,
        shape: pill,
        elevation: 0,
        animationDuration: const Duration(milliseconds: 160),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 56),
        foregroundColor: kInk,
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFFEBDDD4)),
        shape: pill,
        animationDuration: const Duration(milliseconds: 160),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: kAccentDeep,
        shape: pill,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: kInk),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: kAccentDeep,
      foregroundColor: Colors.white,
      elevation: 0,
      highlightElevation: 0,
      shape: pill,
    ),
    chipTheme: ChipThemeData(
      shape: pill,
      side: const BorderSide(color: Color(0xFFEBDDD4)),
      backgroundColor: Colors.white,
      selectedColor: kAccentSoft,
      showCheckmark: false,
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, color: kInk),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (st) => st.contains(WidgetState.selected)
            ? kAccentDeep
            : const Color(0xFFE3D6CE),
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: kAccentDeep,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: const TextStyle(color: kInkSoft),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: Color(0xFFEBDDD4)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: Color(0xFFEBDDD4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: kAccentDeep, width: 1.6),
      ),
    ),
    dividerColor: kLine,
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: Color(0xFFE3D6CE),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: kInk,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: kInkSoft,
        selectedBackgroundColor: kAccentSoft,
        selectedForegroundColor: kInk,
        side: const BorderSide(color: Color(0xFFEBDDD4)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
  );
}
