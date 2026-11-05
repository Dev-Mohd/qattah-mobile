import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/backup_service.dart';
import '../../core/currency.dart';
import '../../core/onboarding.dart';
import '../../core/router.dart';
import '../../core/theme/hesabna_theme.dart';
import '../../providers/providers.dart';
import '../../widgets/app_widgets.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeValueProvider);
    final accentColor = ref.watch(accentColorValueProvider);
    final density = ref.watch(densityValueProvider);
    final cardStyle = ref.watch(cardStyleValueProvider);
    final creatorName = ref.watch(creatorNameValueProvider);
    final reminder = ref.watch(reminderProvider);
    final smartNotifications = ref.watch(smartNotificationsProvider);

    return Scaffold(
      backgroundColor: context.cBg,
      appBar: AppBar(
        title: const Text('الإعدادات'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: context.goToHome,
        ),
      ),
      body: FadeInWidget(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            context.pagePad,
            context.pagePad,
            context.pagePad,
            HesabnaSpacing.bottomNavPad,
          ),
          children: [
            _PreviewCard(accentColor: accentColor),
            SizedBox(height: context.sectionGap),
            const _SectionTitle('المظهر'),
            _SettingsCard(
              children: [
                _SettingRow(
                  icon: Icons.person_outline,
                  title: 'اسم المستخدم',
                  subtitle: creatorName,
                  onTap: () => _showNameSheet(context, ref, creatorName),
                ),
                _SettingRow(
                  icon: Icons.dark_mode_outlined,
                  title: 'المظهر',
                  subtitle: _themeLabel(themeMode),
                  onTap: () => _showThemeSheet(context, ref, themeMode),
                ),
                _SettingRow(
                  icon: Icons.palette_outlined,
                  title: 'لون الهوية',
                  trailing: _AccentPicker(
                    current: accentColor,
                    onSelect: (color) =>
                        ref.read(accentColorProvider.notifier).setColor(color),
                  ),
                ),
                _SettingRow(
                  icon: Icons.compress_outlined,
                  title: 'كثافة العناصر',
                  subtitle: density == AppDensity.compact ? 'مضغوطة' : 'مريحة',
                  onTap: () => _showDensitySheet(context, ref, density),
                ),
                _SettingRow(
                  icon: Icons.crop_square_rounded,
                  title: 'نمط البطاقات',
                  subtitle: _cardStyleLabel(cardStyle),
                  onTap: () => _showCardStyleSheet(context, ref, cardStyle),
                ),
              ],
            ),
            SizedBox(height: context.sectionGap),
            const _SectionTitle('التذكيرات'),
            _SettingsCard(
              children: [
                _SettingRow(
                  icon: Icons.notifications_active_outlined,
                  title: 'تذكير يومي',
                  subtitle: reminder.enabled
                      ? 'سيذكرك يومياً الساعة ${TimeOfDay(hour: reminder.hour, minute: reminder.minute).format(context)}'
                      : 'غير مفعّل',
                  trailing: Switch.adaptive(
                    value: reminder.enabled,
                    activeThumbColor: context.accentColor,
                    onChanged: (enabled) async {
                      final ok = await ref
                          .read(reminderProvider.notifier)
                          .setEnabled(enabled);
                      if (!ok && context.mounted) {
                        _showSnack(context, 'تعذر تفعيل التنبيهات');
                      }
                    },
                  ),
                ),
                _SettingRow(
                  icon: Icons.schedule_outlined,
                  title: 'وقت التذكير',
                  subtitle: TimeOfDay(
                    hour: reminder.hour,
                    minute: reminder.minute,
                  ).format(context),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                        hour: reminder.hour,
                        minute: reminder.minute,
                      ),
                    );
                    if (picked == null) return;
                    final ok = await ref
                        .read(reminderProvider.notifier)
                        .setTime(picked.hour, picked.minute);
                    if (!ok && context.mounted) {
                      _showSnack(context, 'تعذر تحديث وقت التذكير');
                    }
                  },
                ),
                _SettingRow(
                  icon: Icons.auto_awesome_rounded,
                  title: 'التنبيهات الذكية',
                  subtitle: smartNotifications.enabled
                      ? 'تظهر في الصفحة الرئيسية'
                      : 'متوقفة',
                  trailing: Switch.adaptive(
                    value: smartNotifications.enabled,
                    activeThumbColor: context.accentColor,
                    onChanged: (enabled) async {
                      await ref
                          .read(smartNotificationsProvider.notifier)
                          .setEnabled(enabled);
                      if (reminder.enabled) {
                        await ref
                            .read(reminderProvider.notifier)
                            .setTime(reminder.hour, reminder.minute);
                      }
                    },
                  ),
                ),
                if (smartNotifications.enabled)
                  _SettingRow(
                    icon: Icons.tips_and_updates_outlined,
                    title: 'طريقة عرض التنبيهات الذكية',
                    subtitle: smartNotifications.includeInDailyReminder
                        ? 'داخل التطبيق + التذكير اليومي'
                        : 'داخل التطبيق فقط',
                    onTap: () => _showSmartNotificationsSheet(
                      context,
                      ref,
                      smartNotifications,
                      reminder,
                    ),
                  ),
              ],
            ),
            SizedBox(height: context.sectionGap),
            const _SectionTitle('البيانات'),
            _SettingsCard(
              children: [
                _SettingRow(
                  icon: Icons.backup_outlined,
                  title: 'تصدير نسخة احتياطية',
                  subtitle: 'ملف JSON يحتوي بيانات التطبيق',
                  onTap: () => _exportBackup(context),
                ),
                _SettingRow(
                  icon: Icons.restore_outlined,
                  title: 'استيراد نسخة احتياطية',
                  subtitle: 'استعادة بيانات من ملف سابق',
                  onTap: () => _importBackup(context, ref),
                ),
                _SettingRow(
                  icon: Icons.delete_forever_outlined,
                  title: 'حذف كل البيانات',
                  subtitle: 'يحذف القوائم والأعضاء والسجلات والسدادات',
                  danger: true,
                  onTap: () => _deleteAll(context, ref),
                ),
              ],
            ),
            SizedBox(height: context.sectionGap),
            const _SectionTitle('عن التطبيق'),
            _SettingsCard(
              children: [
                _SettingRow(
                  icon: Icons.privacy_tip_outlined,
                  title: 'الشروط والخصوصية',
                  onTap: context.goToLegal,
                ),
                _SettingRow(
                  icon: Icons.info_outline,
                  title: 'عن التطبيق',
                  onTap: context.goToAbout,
                ),
                _SettingRow(
                  icon: Icons.school_outlined,
                  title: 'الجولة التعريفية',
                  subtitle: 'إعادة عرض شرح البداية',
                  onTap: () => _restartTraining(context),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              'صنع بواسطة DevMohd',
              textAlign: TextAlign.center,
              style: HesabnaTypography.caption(color: context.cTextMuted),
            ),
          ],
        ),
      ),
    );
  }

  static String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'فاتح',
        ThemeMode.dark => 'داكن',
        ThemeMode.system => 'تلقائي',
      };

  static String _cardStyleLabel(AppCardStyle style) => switch (style) {
        AppCardStyle.bordered => 'بحدود',
        AppCardStyle.flat => 'مسطح',
        AppCardStyle.shadow => 'بظل',
      };

  static Future<void> _exportBackup(BuildContext context) async {
    try {
      final file = await const BackupService().exportJson();
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'نسخة احتياطية من تطبيق قطه',
        ),
      );
    } catch (e) {
      if (context.mounted) _showSnack(context, 'تعذر تصدير النسخة: $e');
    }
  }

  static Future<void> _importBackup(BuildContext context, WidgetRef ref) async {
    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(label: 'JSON', extensions: ['json']),
        ],
        confirmButtonText: 'استيراد',
      );
      if (file?.path == null) return;

      await const BackupService().importJsonFile(File(file!.path));
      _refreshData(ref);
      if (context.mounted) _showSnack(context, 'تم استيراد النسخة الاحتياطية');
    } catch (e) {
      if (context.mounted) _showSnack(context, 'تعذر الاستيراد: $e');
    }
  }

  static Future<void> _deleteAll(BuildContext context, WidgetRef ref) async {
    final ok = await showAppConfirmSheet(
      context,
      title: 'حذف كل البيانات؟',
      message:
          'سيتم حذف القوائم والأعضاء والوجبات والسجلات والسدادات من هذا الجهاز.',
      destructive: true,
    );
    if (!ok) return;

    try {
      await const BackupService().deleteAll();
      _refreshData(ref);
      if (context.mounted) {
        _showSnack(context, 'تم حذف كل البيانات');
        context.goToHome();
      }
    } catch (e) {
      if (context.mounted) _showSnack(context, 'تعذر حذف البيانات: $e');
    }
  }

  static Future<void> _restartTraining(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(homeTourSeenKey, false);
    if (context.mounted) context.goToOnboarding();
  }

  static void _refreshData(WidgetRef ref) {
    ref.invalidate(listsProvider);
  }

  static void _showThemeSheet(
    BuildContext context,
    WidgetRef ref,
    ThemeMode current,
  ) {
    _showPickerSheet<ThemeMode>(
      context,
      title: 'المظهر',
      selected: current,
      items: const {
        ThemeMode.system: 'تلقائي',
        ThemeMode.light: 'فاتح',
        ThemeMode.dark: 'داكن',
      },
      onSelect: (value) => ref.read(themeModeProvider.notifier).setMode(value),
    );
  }

  static void _showDensitySheet(
    BuildContext context,
    WidgetRef ref,
    AppDensity current,
  ) {
    _showPickerSheet<AppDensity>(
      context,
      title: 'كثافة العناصر',
      selected: current,
      items: const {
        AppDensity.comfortable: 'مريحة',
        AppDensity.compact: 'مضغوطة',
      },
      onSelect: (value) => ref.read(densityProvider.notifier).setDensity(value),
    );
  }

  static void _showCardStyleSheet(
    BuildContext context,
    WidgetRef ref,
    AppCardStyle current,
  ) {
    _showPickerSheet<AppCardStyle>(
      context,
      title: 'نمط البطاقات',
      selected: current,
      items: const {
        AppCardStyle.bordered: 'بحدود',
        AppCardStyle.flat: 'مسطح',
        AppCardStyle.shadow: 'بظل',
      },
      onSelect: (value) => ref.read(cardStyleProvider.notifier).setStyle(value),
    );
  }

  static void _showSmartNotificationsSheet(
    BuildContext context,
    WidgetRef ref,
    SmartNotificationsSettings current,
    ReminderSettings reminder,
  ) {
    _showPickerSheet<bool>(
      context,
      title: 'طريقة عرض التنبيهات الذكية',
      selected: current.includeInDailyReminder,
      items: const {
        false: 'داخل التطبيق فقط',
        true: 'داخل التطبيق + التذكير اليومي',
      },
      onSelect: (value) async {
        await ref
            .read(smartNotificationsProvider.notifier)
            .setIncludeInDailyReminder(value);
        if (reminder.enabled) {
          await ref
              .read(reminderProvider.notifier)
              .setTime(reminder.hour, reminder.minute);
        }
      },
    );
  }

  static void _showNameSheet(
    BuildContext context,
    WidgetRef ref,
    String currentName,
  ) {
    final controller = TextEditingController(text: currentName);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cBg,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(HesabnaRadius.xl)),
      ),
      builder: (sheetContext) {
        final bottom = MediaQuery.of(sheetContext).viewInsets.bottom;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'اسم المستخدم',
                  style: HesabnaTypography.heading(color: context.cText),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  style: HesabnaTypography.body(color: context.cText),
                  decoration: const InputDecoration(
                    labelText: 'الاسم',
                    hintText: 'مثال: محمد',
                  ),
                  onSubmitted: (_) =>
                      _saveName(sheetContext, ref, controller.text),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () =>
                      _saveName(sheetContext, ref, controller.text),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('حفظ الاسم'),
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(controller.dispose);
  }

  static Future<void> _saveName(
    BuildContext context,
    WidgetRef ref,
    String name,
  ) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      _showSnack(context, 'اكتب اسم المستخدم');
      return;
    }
    await ref.read(creatorNameProvider.notifier).setName(trimmed);
    if (context.mounted) Navigator.pop(context);
  }

  static void _showPickerSheet<T>(
    BuildContext context, {
    required String title,
    required T selected,
    required Map<T, String> items,
    required ValueChanged<T> onSelect,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.cBg,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(HesabnaRadius.xl)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title,
                  style: HesabnaTypography.heading(color: context.cText)),
              const SizedBox(height: 12),
              ...items.entries.map(
                (entry) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    entry.value,
                    style: HesabnaTypography.body(color: context.cText),
                  ),
                  trailing: selected == entry.key
                      ? Icon(Icons.check_rounded, color: context.accentColor)
                      : null,
                  onTap: () {
                    onSelect(entry.key);
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void _showSnack(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _PreviewCard extends StatelessWidget {
  final Color accentColor;

  const _PreviewCard({required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: accentColor,
        borderRadius: BorderRadius.circular(HesabnaRadius.lg),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'قطه',
                  style: HesabnaTypography.heading(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  'معاينة للون والهوية',
                  style: HesabnaTypography.caption(
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(HesabnaRadius.md),
            ),
            child: Text(
              '45 $saudiRiyalSymbol',
              style: HesabnaTypography.amountSmall(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child:
          Text(title, style: HesabnaTypography.label(color: context.cTextSub)),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cCard,
        borderRadius: BorderRadius.circular(HesabnaRadius.lg),
        border: context.cardStyle == AppCardStyle.bordered
            ? Border.all(color: context.cBorder)
            : null,
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(height: 1, indent: 16, color: context.cDivider),
          ],
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;

  const _SettingRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? HesabnaColors.lightDanger : context.cText;
    final iconColor = danger ? HesabnaColors.lightDanger : context.cTextSub;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: danger
                    ? HesabnaColors.lightDanger.withValues(alpha: 0.10)
                    : context.cHover,
                borderRadius: BorderRadius.circular(HesabnaRadius.md),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: HesabnaTypography.body(color: color)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style:
                          HesabnaTypography.caption(color: context.cTextMuted),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null)
              Icon(Icons.chevron_left_rounded, color: context.cTextMuted),
          ],
        ),
      ),
    );
  }
}

class _AccentPicker extends StatelessWidget {
  final Color current;
  final ValueChanged<Color> onSelect;

  const _AccentPicker({
    required this.current,
    required this.onSelect,
  });

  static const _colors = [
    Color(0xFF10B981),
    Color(0xFF2563EB),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: _colors.map((color) {
        final selected = color.toARGB32() == current.toARGB32();
        return GestureDetector(
          onTap: () => onSelect(color),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: selected ? 22 : 18,
            height: selected ? 22 : 18,
            margin: const EdgeInsetsDirectional.only(start: 8),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border:
                  selected ? Border.all(color: context.cText, width: 2) : null,
            ),
          ),
        );
      }).toList(),
    );
  }
}
