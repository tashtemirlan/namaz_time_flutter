import 'package:flutter/material.dart';

/// All semantic color tokens for the "Lemongrass & Parchment" design system.
/// Access via context.appColors — never hardcode Color values in widgets.
class AppColors extends ThemeExtension<AppColors> {
  // ─── Semantic tokens ─────────────────────────────────────────────────────
  final Color background;
  final Color surface;
  final Color card;
  final Color text;
  final Color textSecondary;
  final Color textTertiary;
  final Color border;
  final Color divider;
  final Color primary;
  final Color primaryDark;
  final Color primaryLight;
  final Color primaryFill;
  final Color primaryPale;
  final Color error;
  final Color success;
  final Color warning;
  final Color disabled;

  const AppColors({
    required this.background,
    required this.surface,
    required this.card,
    required this.text,
    required this.textSecondary,
    required this.textTertiary,
    required this.border,
    required this.divider,
    required this.primary,
    required this.primaryDark,
    required this.primaryLight,
    required this.primaryFill,
    required this.primaryPale,
    required this.error,
    required this.success,
    required this.warning,
    required this.disabled,
  });

  // ─── Static fixed accents ─────────────────────────────────────────────────
  static const Color lemongrass = Color(0xFF5A9A6E);
  static const Color creamWhite = Color(0xFFFDFCF9);
  static const Color peach = Color(0xFFE07848);
  static const Color honeyGold = Color(0xFFC8952A);
  static const Color rose = Color(0xFFD94870);

  // ─── Elevation shadows (green-tinted) ────────────────────────────────────
  static const List<BoxShadow> elevation0 = [];
  static const List<BoxShadow> elevation1 = [
    BoxShadow(color: Color(0x0A1C2B22), blurRadius: 6, offset: Offset(0, 2)),
  ];
  static const List<BoxShadow> elevation2 = [
    BoxShadow(color: Color(0x141C2B22), blurRadius: 14, offset: Offset(0, 5)),
  ];
  static const List<BoxShadow> elevation3 = [
    BoxShadow(color: Color(0x1E1C2B22), blurRadius: 24, offset: Offset(0, 8)),
  ];
  static const List<BoxShadow> glowPrimary = [
    BoxShadow(color: Color(0x305A9A6E), blurRadius: 20, offset: Offset(0, 6)),
  ];
  static const List<BoxShadow> glowCard = [
    BoxShadow(color: Color(0x1A3D7554), blurRadius: 16, offset: Offset(0, 4)),
  ];

  // ─── Light theme ──────────────────────────────────────────────────────────
  static const AppColors light = AppColors(
    background: Color(0xFFF5F2EC),
    surface: Color(0xFFFDFCF9),
    card: Color(0xFFFFFFFF),
    text: Color(0xFF1C2B22),
    textSecondary: Color(0xFF4A6355),
    textTertiary: Color(0xFF86A897),
    border: Color(0xFFD8E6DD),
    divider: Color(0xFFE4EEE7),
    primary: Color(0xFF5A9A6E),
    primaryDark: Color(0xFF3D7554),
    primaryLight: Color(0xFF7AB88A),
    primaryFill: Color(0xFFE8F2EA),
    primaryPale: Color(0xFFC4DCCA),
    error: Color(0xFFD04B6A),
    success: Color(0xFF3D9E72),
    warning: Color(0xFFC8882A),
    disabled: Color(0xFFEAF0EC),
  );

  // ─── Dark theme ───────────────────────────────────────────────────────────
  static const AppColors dark = AppColors(
    background: Color(0xFF141C17),
    surface: Color(0xFF1C261F),
    card: Color(0xFF243028),
    text: Color(0xFFEBF2ED),
    textSecondary: Color(0xFF8AAE97),
    textTertiary: Color(0xFF567A66),
    border: Color(0xFF2E4238),
    divider: Color(0xFF243228),
    primary: Color(0xFF6EAF82),
    primaryDark: Color(0xFF5A9A6E),
    primaryLight: Color(0xFF96C8A2),
    primaryFill: Color(0xFF1E3028),
    primaryPale: Color(0xFF3A5244),
    error: Color(0xFFE87090),
    success: Color(0xFF5CC492),
    warning: Color(0xFFE0A840),
    disabled: Color(0xFF243028),
  );

  @override
  AppColors copyWith({
    Color? background, Color? surface, Color? card, Color? text,
    Color? textSecondary, Color? textTertiary, Color? border, Color? divider,
    Color? primary, Color? primaryDark, Color? primaryLight, Color? primaryFill,
    Color? primaryPale, Color? error, Color? success, Color? warning, Color? disabled,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      card: card ?? this.card,
      text: text ?? this.text,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      primary: primary ?? this.primary,
      primaryDark: primaryDark ?? this.primaryDark,
      primaryLight: primaryLight ?? this.primaryLight,
      primaryFill: primaryFill ?? this.primaryFill,
      primaryPale: primaryPale ?? this.primaryPale,
      error: error ?? this.error,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      disabled: disabled ?? this.disabled,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!,
      text: Color.lerp(text, other.text, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      border: Color.lerp(border, other.border, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      primaryFill: Color.lerp(primaryFill, other.primaryFill, t)!,
      primaryPale: Color.lerp(primaryPale, other.primaryPale, t)!,
      error: Color.lerp(error, other.error, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      disabled: Color.lerp(disabled, other.disabled, t)!,
    );
  }
}
