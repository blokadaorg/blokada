import 'package:common/common/widget.dart';
import 'package:flutter/material.dart';

class CommonDivider extends StatelessWidget {
  final double indent;

  const CommonDivider({super.key, this.indent = 44});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: indent,
      color: context.theme.shadow,
    );
  }
}
