import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_extensions.dart';
import 'app_text.dart';

enum AppButtonVariant { primary, ghost, outline, destructive }

class AppButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool loading;
  final bool expand;
  final IconData? icon;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
    this.expand = false,
    this.icon,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final enabled = widget.onPressed != null && !widget.loading;

    Widget child = widget.loading
        ? SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: widget.variant == AppButtonVariant.primary
                  ? AppColors.creamWhite
                  : colors.primary,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 18,
                  color: _textColor(colors, widget.variant)),
                const SizedBox(width: 8),
              ],
              AppText(
                text: widget.text,
                fontSize: 16, fontWeight: FontWeight.w600,
                color: _textColor(colors, widget.variant),
                letterSpacing: 0.1,
              ),
            ],
          );

    if (widget.expand) {
      child = Center(child: child);
    }

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTap: enabled ? widget.onPressed : null,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: widget.expand ? double.infinity : null,
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: _decoration(colors, widget.variant, enabled),
          child: child,
        ),
      ),
    );
  }

  BoxDecoration _decoration(AppColors colors, AppButtonVariant v, bool enabled) {
    switch (v) {
      case AppButtonVariant.primary:
        return BoxDecoration(
          gradient: enabled
              ? const LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color(0xFF5A9A6E), Color(0xFF7AB88A)],
                )
              : null,
          color: enabled ? null : colors.disabled,
          borderRadius: BorderRadius.circular(8),
          boxShadow: enabled ? AppColors.glowPrimary : [],
        );
      case AppButtonVariant.ghost:
        return BoxDecoration(
          color: colors.primaryFill,
          borderRadius: BorderRadius.circular(8),
        );
      case AppButtonVariant.outline:
        return BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.primary, width: 1.5),
        );
      case AppButtonVariant.destructive:
        return BoxDecoration(
          color: const Color(0xFFFDEAF0),
          borderRadius: BorderRadius.circular(8),
        );
    }
  }

  Color _textColor(AppColors colors, AppButtonVariant v) {
    switch (v) {
      case AppButtonVariant.primary:    return AppColors.creamWhite;
      case AppButtonVariant.ghost:      return colors.primary;
      case AppButtonVariant.outline:    return colors.primary;
      case AppButtonVariant.destructive: return colors.error;
    }
  }
}
