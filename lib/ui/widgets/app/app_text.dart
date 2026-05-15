import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cached text widget. Never call GoogleFonts.*() in build() directly.
/// All text in the app goes through AppText.
class AppText extends StatelessWidget {
  final String text;
  final double? fontSize;
  final FontWeight? fontWeight;
  final Color? color;
  final String? fontFamily; // 'PlayfairDisplay' | 'PlusJakartaSans' (default)
  final double? height;
  final double? letterSpacing;
  final TextDecoration? decoration;
  final FontStyle? fontStyle;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;

  const AppText({
    super.key,
    required this.text,
    this.fontSize,
    this.fontWeight,
    this.color,
    this.fontFamily,
    this.height,
    this.letterSpacing,
    this.decoration,
    this.fontStyle,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
  });

  // ─── Style cache ─────────────────────────────────────────────────────────
  static final Map<int, TextStyle> _cache = {};

  static TextStyle _resolve({
    required String family,
    double? size,
    FontWeight? weight,
    Color? color,
    double? height,
    double? letterSpacing,
    TextDecoration? decoration,
    FontStyle? style,
  }) {
    final key = Object.hash(family, size, weight, color, height, letterSpacing, decoration, style);
    return _cache.putIfAbsent(key, () {
      final base = family == 'PlayfairDisplay'
          ? GoogleFonts.playfairDisplay(
              fontSize: size,
              fontWeight: weight,
              color: color,
              height: height,
              letterSpacing: letterSpacing,
              decoration: decoration,
              fontStyle: style,
            )
          : GoogleFonts.plusJakartaSans(
              fontSize: size,
              fontWeight: weight,
              color: color,
              height: height,
              letterSpacing: letterSpacing,
              decoration: decoration,
              fontStyle: style,
            );
      return base;
    });
  }

  @override
  Widget build(BuildContext context) {
    final style = _resolve(
      family: fontFamily ?? 'PlusJakartaSans',
      size: fontSize,
      weight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      decoration: decoration,
      style: fontStyle,
    );

    return Text(
      text,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
    );
  }
}
