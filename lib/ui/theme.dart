import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

// Цвета, которые не меняются между светлой и тёмной темой.
const kAccent = Color(0xFFF2A88F);
const kAccentDeep = Color(0xFFE58E70);
const kOnPastel = Color(0xFF4A3F3A); // текст на пастельных плашках участников

class _Palette {
  final Color bg,
      bgTop,
      surface,
      ink,
      inkSoft,
      line,
      accentSoft,
      switchOff,
      field,
      border,
      cardBorder,
      warnBg,
      errBg,
      hero1,
      hero2,
      outMonth,
      faint,
      placeholder,
      common;
  const _Palette({
    required this.bg,
    required this.bgTop,
    required this.surface,
    required this.ink,
    required this.inkSoft,
    required this.line,
    required this.accentSoft,
    required this.switchOff,
    required this.field,
    required this.border,
    required this.cardBorder,
    required this.warnBg,
    required this.errBg,
    required this.hero1,
    required this.hero2,
    required this.outMonth,
    required this.faint,
    required this.placeholder,
    required this.common,
  });
}

const _light = _Palette(
  bg: Color(0xFFFFF8F3),
  bgTop: Color(0xFFFFEFE4),
  surface: Colors.white,
  ink: Color(0xFF4A3F3A),
  inkSoft: Color(0xFF8C7F78),
  line: Color(0xFFF1E3DA),
  accentSoft: Color(0xFFFCE3D9),
  switchOff: Color(0xFFE3D6CE),
  field: Color(0xFFFFF6F0),
  border: Color(0xFFEBDDD4),
  cardBorder: Color(0xFFF4E8E0),
  warnBg: Color(0xFFFFF1D6),
  errBg: Color(0xFFFFE3E0),
  hero1: Color(0xFFFFE0D2),
  hero2: Color(0xFFFBD3E0),
  outMonth: Color(0xFFFFFCFA),
  faint: Color(0xFFD3C8C1),
  placeholder: Color(0xFFF1E6DF),
  common: Color(0xFFFFE3EA),
);

const _dark = _Palette(
  bg: Color(0xFF1B1614),
  bgTop: Color(0xFF261C19),
  surface: Color(0xFF28211E),
  ink: Color(0xFFF4EAE4),
  inkSoft: Color(0xFFB0A199),
  line: Color(0xFF3A302C),
  accentSoft: Color(0xFF4A2F27),
  switchOff: Color(0xFF4E433E),
  field: Color(0xFF332A26),
  border: Color(0xFF4A3F3A),
  cardBorder: Color(0xFF362D29),
  warnBg: Color(0xFF4A3B22),
  errBg: Color(0xFF4F2D2B),
  hero1: Color(0xFF4A2E26),
  hero2: Color(0xFF462A3A),
  outMonth: Color(0xFF211A18),
  faint: Color(0xFF5E514B),
  placeholder: Color(0xFF3A302C),
  common: Color(0xFF45283A),
);

// Текущие цвета. Меняются при смене темы (см. applyPalette).
bool kDark = false;
Color kBg = _light.bg;
Color kBgTop = _light.bgTop;
Color kSurface = _light.surface;
Color kInk = _light.ink;
Color kInkSoft = _light.inkSoft;
Color kLine = _light.line;
Color kAccentSoft = _light.accentSoft;
Color kSwitchOff = _light.switchOff;
Color kField = _light.field;
Color kBorder = _light.border;
Color kCardBorder = _light.cardBorder;
Color kWarnBg = _light.warnBg;
Color kErrBg = _light.errBg;
Color kHero1 = _light.hero1;
Color kHero2 = _light.hero2;
Color kOutMonth = _light.outMonth;
Color kFaint = _light.faint;
Color kPlaceholder = _light.placeholder;
Color kCommon = _light.common;

void applyPalette(bool dark) {
  final p = dark ? _dark : _light;
  kDark = dark;
  kBg = p.bg;
  kBgTop = p.bgTop;
  kSurface = p.surface;
  kInk = p.ink;
  kInkSoft = p.inkSoft;
  kLine = p.line;
  kAccentSoft = p.accentSoft;
  kSwitchOff = p.switchOff;
  kField = p.field;
  kBorder = p.border;
  kCardBorder = p.cardBorder;
  kWarnBg = p.warnBg;
  kErrBg = p.errBg;
  kHero1 = p.hero1;
  kHero2 = p.hero2;
  kOutMonth = p.outMonth;
  kFaint = p.faint;
  kPlaceholder = p.placeholder;
  kCommon = p.common;
}

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
  final dark = kDark;
  final scheme = ColorScheme.fromSeed(
    seedColor: kAccent,
    brightness: dark ? Brightness.dark : Brightness.light,
  ).copyWith(primary: kAccentDeep, surface: kSurface, onSurface: kInk);

  const pill = StadiumBorder();
  const cupertino = CupertinoPageTransitionsBuilder();

  return ThemeData(
    useMaterial3: true,
    brightness: dark ? Brightness.dark : Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: kSurface,
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
    textTheme:
        (dark
                ? Typography.material2021().white
                : Typography.material2021().black)
            .apply(bodyColor: kInk, displayColor: kInk),
    appBarTheme: AppBarTheme(
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
      color: kSurface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: kSurface,
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
        backgroundColor: kSurface,
        side: BorderSide(color: kBorder),
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
      side: BorderSide(color: kBorder),
      backgroundColor: kSurface,
      selectedColor: kAccentSoft,
      showCheckmark: false,
      labelStyle: TextStyle(fontWeight: FontWeight.w700, color: kInk),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (st) => st.contains(WidgetState.selected) ? kAccentDeep : kSwitchOff,
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: kAccentDeep,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSurface,
      hintStyle: TextStyle(color: kInkSoft),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide(color: kBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide(color: kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: kAccentDeep, width: 1.6),
      ),
    ),
    dividerColor: kLine,
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: kSurface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: kSwitchOff,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: kSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: kInk,
      contentTextStyle: TextStyle(color: kBg, fontSize: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: kSurface,
        foregroundColor: kInkSoft,
        selectedBackgroundColor: kAccentSoft,
        selectedForegroundColor: kInk,
        side: BorderSide(color: kBorder),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
  );
}
