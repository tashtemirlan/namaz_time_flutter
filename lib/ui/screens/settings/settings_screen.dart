import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/prayer_provider.dart';
import '../../../services/notification_service.dart';
import '../../../global/app_settings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_extensions.dart';
import '../../widgets/app/app_text.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _prayers = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
  static const _beforeOptions = [0, 5, 10, 15, 20, 30];

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildHeader(colors),
            SliverList(
              delegate: SliverChildListDelegate([
                // ─── Appearance ───────────────────────────────────────────
                _SectionHeader(title: 'settings.appearance'.tr(), colors: colors),
                _SettingCard(
                  colors: colors,
                  children: [
                    ValueListenableBuilder<ThemeMode>(
                      valueListenable: AppSettings.themeMode,
                      builder: (_, mode, __) => _SwitchTile(
                        icon: mode == ThemeMode.dark
                            ? Icons.nights_stay_rounded
                            : Icons.wb_sunny_rounded,
                        title: 'settings.dark_mode'.tr(),
                        value: mode == ThemeMode.dark,
                        onChanged: (_) => AppSettings.toggleTheme(),
                        colors: colors,
                      ),
                    ),
                  ],
                ),

                // ─── Language ─────────────────────────────────────────────
                _SectionHeader(title: 'settings.language'.tr(), colors: colors),
                _SettingCard(
                  colors: colors,
                  children: [
                    _LanguageTile(colors: colors),
                  ],
                ),

                // ─── Notifications ────────────────────────────────────────
                _SectionHeader(title: 'settings.notifications'.tr(), colors: colors),
                _SettingCard(
                  colors: colors,
                  children: [
                    ..._prayers.asMap().entries.map((e) => _SwitchTile(
                      icon: _prayerIcon(e.value),
                      title: 'prayers.${e.value}'.tr(),
                      value: settings.isEnabled(e.value),
                      onChanged: (v) async {
                        await settings.setNotifEnabled(e.value, v);
                        if (!context.mounted) return;
                        await _reschedule(context);
                      },
                      colors: colors,
                      showDivider: e.key < _prayers.length - 1,
                    )),
                  ],
                ),

                // Notify before picker
                _SectionHeader(
                  title: 'settings.notify_before'
                      .tr(namedArgs: {'min': ''}),
                  colors: colors,
                ),
                _SettingCard(
                  colors: colors,
                  children: [
                    _BeforeMinPicker(
                      options: _beforeOptions,
                      selected: settings.notifBeforeMin,
                      onSelect: (v) async {
                        await settings.setNotifBeforeMin(v);
                        if (!context.mounted) return;
                        await _reschedule(context);
                      },
                      colors: colors,
                    ),
                  ],
                ),

                // ─── Sound ────────────────────────────────────────────────
                _SectionHeader(title: 'settings.sound'.tr(), colors: colors),
                _SettingCard(
                  colors: colors,
                  children: [
                    _SwitchTile(
                      icon: settings.soundEnabled
                          ? Icons.volume_up_rounded
                          : Icons.volume_off_rounded,
                      title: 'settings.sound_toggle'.tr(),
                      subtitle: 'settings.sound_hint'.tr(),
                      value: settings.soundEnabled,
                      onChanged: (v) async {
                        await settings.setSoundEnabled(v);
                        if (!context.mounted) return;
                        await _reschedule(context);
                      },
                      colors: colors,
                      showDivider: true,
                    ),
                    _AzanSoundModePicker(
                      currentMode: settings.azanSoundMode,
                      customSoundUri: settings.customSoundUri,
                      enabled: settings.soundEnabled,
                      colors: colors,
                      onModeSelected: (mode) async {
                        if (mode == AppSettings.azanSoundModeCustom) {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.audio,
                          );
                          final path = result?.files.single.path;
                          if (path == null) return;
                          await settings.setCustomSoundUri('file://$path');
                          await settings.setAzanSoundMode(
                              AppSettings.azanSoundModeCustom);
                        } else {
                          await settings.setAzanSoundMode(mode);
                        }
                        if (!context.mounted) return;
                        await _reschedule(context);
                      },
                      displayNameFromUri: _displayNameFromUri,
                    ),
                    _ActionTile(
                      icon: Icons.notifications_active_rounded,
                      title: 'settings.test_notification'.tr(),
                      subtitle: 'settings.test_notification_hint'.tr(),
                      onTap: () async {
                        await NotificationService.showTestNotification(
                          AppSettings.language,
                        );
                      },
                      colors: colors,
                    ),
                  ],
                ),

                // ─── About ────────────────────────────────────────────────
                _SectionHeader(title: 'settings.about'.tr(), colors: colors),
                _SettingCard(
                  colors: colors,
                  children: [
                    _InfoTile(
                      icon: Icons.info_outline_rounded,
                      title: 'settings.version'.tr(namedArgs: {'v': '1.0.0'}),
                      colors: colors,
                    ),
                    _InfoTile(
                      icon: Icons.person_outline_rounded,
                      title: 'settings.developed_by'.tr(),
                      colors: colors,
                    ),
                  ],
                ),

                const SizedBox(height: 96),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  String _displayNameFromUri(String uri) {
    final clean = uri.replaceFirst('file://', '');
    if (clean.isEmpty) return uri;
    return clean.split('/').last;
  }

  /// Re-schedule notifications with the latest settings.
  Future<void> _reschedule(BuildContext context) async {
    final prayer = context.read<PrayerProvider>();
    final times = prayer.times;
    if (times == null) return;
    await NotificationService.schedulePrayerNotifications(
        times, AppSettings.language);
  }

  Widget _buildHeader(AppColors colors) {
    return SliverToBoxAdapter(
      child: Container(
        color: colors.surface,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: AppText(
          text: 'settings.title'.tr(),
          fontSize: 24,
          fontWeight: FontWeight.w700,
          fontFamily: 'PlayfairDisplay',
          color: colors.text,
        ),
      ),
    );
  }

  IconData _prayerIcon(String p) {
    switch (p) {
      case 'fajr':    return Icons.wb_twilight_rounded;
      case 'dhuhr':   return Icons.wb_sunny_rounded;
      case 'asr':     return Icons.sunny_snowing;
      case 'maghrib': return Icons.wb_twilight_rounded;
      case 'isha':    return Icons.nights_stay_rounded;
      default:        return Icons.access_time_rounded;
    }
  }
}

// ─── Azan Sound Mode Picker ───────────────────────────────────────────────

class _AzanSoundModePicker extends StatelessWidget {
  final String currentMode;
  final String? customSoundUri;
  final bool enabled;
  final AppColors colors;
  final Future<void> Function(String mode) onModeSelected;
  final String Function(String uri) displayNameFromUri;

  const _AzanSoundModePicker({
    required this.currentMode,
    required this.customSoundUri,
    required this.enabled,
    required this.colors,
    required this.onModeSelected,
    required this.displayNameFromUri,
  });

  @override
  Widget build(BuildContext context) {
    final options = [
      (
        mode: AppSettings.azanSoundModeSystem,
        icon: Icons.notifications_rounded,
        label: 'settings.sound_system'.tr(),
        subtitle: 'settings.sound_system_hint'.tr(),
      ),
      (
        mode: AppSettings.azanSoundModeDefaultAzan,
        icon: Icons.surround_sound_rounded,
        label: 'settings.sound_default_azan'.tr(),
        subtitle: 'settings.sound_default_azan_hint'.tr(),
      ),
      (
        mode: AppSettings.azanSoundModeCustom,
        icon: Icons.audio_file_rounded,
        label: 'settings.azan_ringtone'.tr(),
        subtitle: currentMode == AppSettings.azanSoundModeCustom &&
                customSoundUri != null
            ? displayNameFromUri(customSoundUri!)
            : 'settings.azan_ringtone_pick'.tr(),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppText(
              text: 'settings.azan_ringtone'.tr(),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: enabled ? colors.textSecondary : colors.textTertiary,
            ),
          ),
          ...options.asMap().entries.map((e) {
            final opt = e.value;
            final isSelected = currentMode == opt.mode;
            final isLast = e.key == options.length - 1;
            return Column(
              children: [
                InkWell(
                  onTap: enabled ? () => onModeSelected(opt.mode) : null,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isSelected && enabled
                                ? colors.primaryFill
                                : colors.background,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            opt.icon,
                            size: 18,
                            color: isSelected && enabled
                                ? colors.primary
                                : colors.textTertiary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppText(
                                text: opt.label,
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: enabled
                                    ? colors.text
                                    : colors.textTertiary,
                              ),
                              AppText(
                                text: opt.subtitle,
                                fontSize: 11,
                                color: colors.textTertiary,
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 20,
                          color: isSelected && enabled
                              ? colors.primary
                              : colors.textTertiary,
                        ),
                      ],
                    ),
                  ),
                ),
                if (!isLast)
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    color: colors.divider,
                    indent: 52,
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ─── Language Tile ────────────────────────────────────────────────────────

class _LanguageTile extends StatelessWidget {
  final AppColors colors;
  const _LanguageTile({required this.colors});

  @override
  Widget build(BuildContext ctx) {
    final langs = [
      ('ru', 'settings.lang_ru'.tr()),
      ('ky', 'settings.lang_ky'.tr()),
      ('en', 'settings.lang_en'.tr()),
    ];
    final current = AppSettings.language;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            text: 'settings.language'.tr(),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colors.text,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: langs.map((l) {
              final isSelected = l.$1 == current;
              return GestureDetector(
                onTap: () async {
                  await AppSettings.setLanguage(l.$1);
                  if (ctx.mounted) {
                    await ctx.setLocale(Locale(l.$1));
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? colors.primary : colors.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isSelected ? colors.primary : colors.border,
                      width: 1.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                                color: colors.primary.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 3))
                          ]
                        : [],
                  ),
                  child: AppText(
                    text: l.$2,
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? Colors.white : colors.text,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─── Before Minutes Picker ────────────────────────────────────────────────

class _BeforeMinPicker extends StatelessWidget {
  final List<int> options;
  final int selected;
  final void Function(int) onSelect;
  final AppColors colors;

  const _BeforeMinPicker({
    required this.options,
    required this.selected,
    required this.onSelect,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.map((min) {
          final isSelected = min == selected;
          return GestureDetector(
            onTap: () => onSelect(min),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 56,
              height: 42,
              decoration: BoxDecoration(
                color: isSelected ? colors.primary : colors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? colors.primary : colors.border,
                  width: 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                            color: colors.primary.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 3))
                      ]
                    : [],
              ),
              child: Center(
                child: AppText(
                  text: min == 0 ? '—' : '${min}m',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : colors.text,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Shared components ────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final AppColors colors;
  const _SectionHeader({required this.title, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: AppText(
        text: title.toUpperCase(),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: colors.textSecondary,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  final List<Widget> children;
  final AppColors colors;
  const _SettingCard({required this.children, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
        boxShadow: AppColors.elevation1,
      ),
      child: Column(children: children),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final AppColors colors;
  final bool showDivider;

  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    required this.colors,
    this.subtitle,
    this.showDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: value ? colors.primaryFill : colors.background,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon,
                    size: 20,
                    color: value ? colors.primary : colors.textTertiary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      text: title,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: colors.text,
                    ),
                    if (subtitle != null)
                      AppText(
                        text: subtitle!,
                        fontSize: 12,
                        color: colors.textTertiary,
                      ),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: colors.primary,
                activeTrackColor: colors.primaryLight,
                inactiveThumbColor: colors.textTertiary,
                inactiveTrackColor: colors.disabled,
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
              height: 1,
              thickness: 0.5,
              color: colors.divider,
              indent: 66),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final AppColors colors;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: colors.primaryFill,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: colors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AppText(
              text: title,
              fontSize: 15,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Future<void> Function() onTap;
  final AppColors colors;
  final bool showDivider;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    required this.colors,
    this.subtitle,
    this.showDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: colors.primaryFill,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, size: 20, color: colors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        text: title,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: colors.text,
                      ),
                      if (subtitle != null)
                        AppText(
                          text: subtitle!,
                          fontSize: 12,
                          color: colors.textTertiary,
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.textTertiary,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 0.5,
            color: colors.divider,
            indent: 66,
          ),
      ],
    );
  }
}
