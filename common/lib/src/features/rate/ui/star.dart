import 'package:flutter/material.dart';

import 'package:common/src/shared/ui/touch.dart';

class RateStar extends StatefulWidget {
  final bool full;
  final VoidCallback? onTap;

  const RateStar({
    super.key,
    this.onTap,
    required this.full,
  });

  @override
  State<StatefulWidget> createState() => RateStarState();
}

class RateStarState extends State<RateStar> {
  @override
  Widget build(BuildContext context) {
    return Touch(
      onTap: () => widget.onTap?.call(),
      maxValue: 0.4,
      decorationBuilder: (value) {
        return BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(value),
        );
      },
      child: SizedBox(
        height: 60,
        width: 60,
        child: Icon(
          widget.full ? Icons.star : Icons.star_border,
          color: Colors.white,
          size: 40,
        ),
      ),
    );
  }
}
