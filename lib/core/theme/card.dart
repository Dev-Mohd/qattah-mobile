import 'package:flutter/material.dart';
import 'context_extension.dart';
import 'tokens/radius.dart';
import 'tokens/shadows.dart';
import 'enums.dart';

class HesabnaCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? color;
  final VoidCallback? onTap;
  final double? borderRadius;

  const HesabnaCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.onTap,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final style = context.cardStyle;
    final bgColor = color ?? context.cCard;

    Widget card = Container(
      padding: padding ?? EdgeInsets.all(context.cardPad),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(borderRadius ?? HesabnaRadius.lg),
        border: style == AppCardStyle.bordered
            ? Border.all(color: context.cBorder, width: 1)
            : Border.all(color: Colors.transparent, width: 1),
        boxShadow: style == AppCardStyle.shadow ? HesabnaShadow.light : null,
      ),
      child: child,
    );

    if (onTap != null) {
      card = Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius ?? HesabnaRadius.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius ?? HesabnaRadius.lg),
          child: card,
        ),
      );
    }

    return card;
  }
}
