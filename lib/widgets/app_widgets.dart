import 'package:flutter/material.dart';
import '../core/theme/hesabna_theme.dart';

Future<bool> showAppConfirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'حذف',
  String cancelLabel = 'إلغاء',
  IconData icon = Icons.delete_outline_rounded,
  bool destructive = true,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: context.cBg,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(HesabnaRadius.xl)),
    ),
    builder: (sheetContext) {
      final actionColor =
          destructive ? HesabnaColors.lightDanger : context.accentColor;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.cBorder,
                    borderRadius: BorderRadius.circular(HesabnaRadius.full),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: actionColor.withValues(
                          alpha: context.isDark ? 0.18 : 0.10),
                      borderRadius: BorderRadius.circular(HesabnaRadius.md),
                    ),
                    child: Icon(icon, color: actionColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: HesabnaTypography.heading(
                                color: context.cText)),
                        const SizedBox(height: 4),
                        Text(
                          message,
                          style:
                              HesabnaTypography.bodySm(color: context.cTextSub),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.pop(sheetContext, true),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  backgroundColor: actionColor,
                ),
                child: Text(confirmLabel),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext, false),
                child: Text(cancelLabel),
              ),
            ],
          ),
        ),
      );
    },
  );

  return result ?? false;
}

class AppSwipeDelete extends StatelessWidget {
  final String id;
  final Widget child;
  final String title;
  final String message;
  final Future<void> Function() onDelete;
  final String confirmLabel;
  final bool enabled;

  const AppSwipeDelete({
    super.key,
    required this.id,
    required this.child,
    required this.title,
    required this.message,
    required this.onDelete,
    this.confirmLabel = 'حذف',
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return Dismissible(
      key: ValueKey('swipe-delete-$id'),
      direction: DismissDirection.endToStart,
      resizeDuration: null,
      movementDuration: const Duration(milliseconds: 220),
      confirmDismiss: (_) async {
        final ok = await showAppConfirmSheet(
          context,
          title: title,
          message: message,
          confirmLabel: confirmLabel,
        );
        if (!ok) return false;
        await onDelete();
        return false;
      },
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: 18),
        decoration: BoxDecoration(
          color: HesabnaColors.lightDanger
              .withValues(alpha: context.isDark ? 0.24 : 0.12),
          borderRadius: BorderRadius.circular(HesabnaRadius.lg),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'حذف',
              style: HesabnaTypography.caption(color: HesabnaColors.lightDanger)
                  .copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 8),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: HesabnaColors.lightDanger.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(HesabnaRadius.md),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: HesabnaColors.lightDanger,
                size: 20,
              ),
            ),
          ],
        ),
      ),
      child: child,
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  APP ERROR VIEW — مع زر retry
// ════════════════════════════════════════════════════════════════════

class AppErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const AppErrorView({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: HesabnaColors.lightDanger
                    .withValues(alpha: context.isDark ? 0.18 : 0.10),
                borderRadius: BorderRadius.circular(HesabnaRadius.lg),
              ),
              child: const Icon(Icons.error_outline,
                  color: HesabnaColors.lightDanger, size: 28),
            ),
            const SizedBox(height: 16),
            Text('حدث خطأ',
                style: HesabnaTypography.heading(color: context.cText)),
            const SizedBox(height: 6),
            Text(
              message,
              style: HesabnaTypography.bodySm(color: context.cText),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ]),
        ),
      );
}

// ════════════════════════════════════════════════════════════════════
//  APP EMPTY VIEW — حالة فارغة قابلة للتخصيص
// ════════════════════════════════════════════════════════════════════

class AppEmptyView extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppEmptyView({
    super.key,
    required this.icon,
    required this.label,
    required this.sub,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: context.cHover,
                borderRadius: BorderRadius.circular(HesabnaRadius.lg),
              ),
              child: Icon(icon, size: 28, color: context.cTextMuted),
            ),
            const SizedBox(height: 16),
            Text(label,
                style: HesabnaTypography.subtitle(color: context.cText)),
            const SizedBox(height: 4),
            Text(sub,
                style: HesabnaTypography.bodySm(color: context.cText),
                textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ]),
        ),
      );
}

// ════════════════════════════════════════════════════════════════════
//  APP LOADING VIEW — shimmer skeleton
// ════════════════════════════════════════════════════════════════════

class AppLoadingView extends StatefulWidget {
  /// عدد صفوف الـ skeleton
  final int rows;
  final bool card;

  const AppLoadingView({super.key, this.rows = 4, this.card = true});

  @override
  State<AppLoadingView> createState() => _AppLoadingViewState();
}

class _AppLoadingViewState extends State<AppLoadingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final base = context.cHover;
        final shimmer = context.isDark
            ? Colors.white.withValues(alpha: 0.06 * _anim.value)
            : Colors.white.withValues(alpha: 0.6 * _anim.value);
        final color = Color.alphaBlend(shimmer, base);

        Widget skeleton(double w, double h) => Container(
              width: w,
              height: h,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(HesabnaRadius.sm),
              ),
            );

        final rows = List.generate(
            widget.rows,
            (i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(children: [
                    skeleton(40, 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          skeleton(double.infinity, 13),
                          const SizedBox(height: 6),
                          skeleton(120 + (i % 3) * 20, 11),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    skeleton(48, 16),
                  ]),
                ));

        if (!widget.card) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: rows),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: context.cCard,
                borderRadius: BorderRadius.circular(HesabnaRadius.lg),
                border: context.appearance.cardStyle == AppCardStyle.bordered
                    ? Border.all(color: context.cBorder)
                    : null),
            child: Column(children: rows),
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  INLINE ERROR BANNER — للأخطاء داخل الصفحة (بدل spinner)
// ════════════════════════════════════════════════════════════════════

class AppErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const AppErrorBanner({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: HesabnaColors.lightDanger
              .withValues(alpha: context.isDark ? 0.18 : 0.10),
          borderRadius: BorderRadius.circular(HesabnaRadius.md),
          border: Border.all(
              color: HesabnaColors.lightDanger.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline,
              color: HesabnaColors.lightDanger, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: HesabnaTypography.bodySm(color: context.cText)
                    .copyWith(color: HesabnaColors.lightDanger)),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onRetry,
              child: Icon(Icons.refresh_rounded,
                  color: HesabnaColors.lightDanger, size: 16),
            ),
          ],
        ]),
      );
}
