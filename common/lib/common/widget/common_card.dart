import 'package:flutter/material.dart';

import 'theme.dart';

class CommonCard extends StatelessWidget {
  final Color? bgColor;
  final BoxBorder? bgBorder;
  final Widget child;
  final EdgeInsets? padding;
  const CommonCard(
      {super.key,
      this.bgColor,
      required this.child,
      this.padding,
      this.bgBorder});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor ?? context.theme.bgMiniCard,
        border: bgBorder,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: padding ?? EdgeInsets.zero,
          child: child,
        ),
      ),
    );
  }
}
