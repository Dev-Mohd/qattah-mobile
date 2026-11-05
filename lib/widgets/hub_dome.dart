import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/theme/hesabna_theme.dart';

class HubDomeItem {
  final IconData icon;
  final String label;

  const HubDomeItem(this.icon, this.label);
}

class HesabnaHubDome extends StatefulWidget {
  final Animation<double> animation;
  final List<HubDomeItem> items;
  final int initialIndex;
  final void Function(int index) onSelect;

  const HesabnaHubDome({
    super.key,
    required this.animation,
    required this.items,
    required this.onSelect,
    this.initialIndex = 0,
  });

  @override
  State<HesabnaHubDome> createState() => _HesabnaHubDomeState();
}

class _HesabnaHubDomeState extends State<HesabnaHubDome> {
  late int _centerIndex;
  double _dragOffset = 0;

  @override
  void initState() {
    super.initState();
    _centerIndex = widget.initialIndex;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() => _dragOffset += details.delta.dx);
  }

  void _onDragEnd(DragEndDetails _) {
    const threshold = 60.0;
    if (_dragOffset < -threshold && _centerIndex < widget.items.length - 1) {
      setState(() => _centerIndex++);
    } else if (_dragOffset > threshold && _centerIndex > 0) {
      setState(() => _centerIndex--);
    }
    setState(() => _dragOffset = 0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.animation,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, (1 - widget.animation.value) * 80),
        child: Opacity(
          opacity: widget.animation.value,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 88),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  decoration: BoxDecoration(
                    color: context.cSurface
                        .withValues(alpha: context.isDark ? 0.82 : 0.90),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                        color: context.cBorder.withValues(alpha: 0.82)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: context.isDark ? 0.38 : 0.14,
                        ),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 38,
                          height: 4,
                          decoration: BoxDecoration(
                            color: context.cBorder,
                            borderRadius:
                                BorderRadius.circular(HesabnaRadius.full),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onHorizontalDragUpdate: _onDragUpdate,
                        onHorizontalDragEnd: _onDragEnd,
                        child: Row(
                          children: List.generate(widget.items.length, (index) {
                            final item = widget.items[index];
                            final active = index == _centerIndex;

                            return Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                child: _HubSegment(
                                  item: item,
                                  active: active,
                                  onTap: () => active
                                      ? widget.onSelect(_centerIndex)
                                      : setState(() => _centerIndex = index),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HubSegment extends StatelessWidget {
  final HubDomeItem item;
  final bool active;
  final VoidCallback onTap;

  const _HubSegment({
    required this.item,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        height: 70,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: active ? context.accentColor : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: active
                ? context.accentColor
                : context.cBorder.withValues(alpha: 0.45),
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: context.accentColor.withValues(alpha: 0.22),
                    blurRadius: 18,
                    offset: const Offset(0, 7),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              item.icon,
              size: 21,
              color: active ? context.cBg : context.cTextSub,
            ),
            const SizedBox(height: 5),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: HesabnaTypography.caption(
                color: active ? context.cBg : context.cTextSub,
              ).copyWith(
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                height: 1.05,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
