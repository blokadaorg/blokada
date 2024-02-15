import 'package:common/common/widget.dart';
import 'package:flutter/material.dart';

class CommonTextButton extends StatelessWidget {
  final String text;

  const CommonTextButton(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(
          fontSize: 16,
          color: context.theme.accent,
        ));
  }
}
