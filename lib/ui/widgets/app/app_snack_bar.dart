import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_extensions.dart';
import 'app_text.dart';

class AppSnackBar {
  static void success(BuildContext context, {required String title, String? message}) =>
      _show(context, title: title, message: message, accent: AppColors.light.success);

  static void error(BuildContext context, {required String title, String? message}) =>
      _show(context, title: title, message: message, accent: AppColors.light.error);

  static void info(BuildContext context, {required String title, String? message}) =>
      _show(context, title: title, message: message, accent: AppColors.light.primary);

  static void _show(
    BuildContext context, {
    required String title,
    String? message,
    required Color accent,
  }) {
    final colors = context.appColors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: accent, width: 4)),
            boxShadow: AppColors.elevation2,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(text: title, fontSize: 14, fontWeight: FontWeight.w600, color: colors.text),
              if (message != null) ...[
                const SizedBox(height: 2),
                AppText(text: message, fontSize: 13, color: colors.textSecondary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
