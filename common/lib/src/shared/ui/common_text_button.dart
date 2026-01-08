import 'package:flutter/material.dart';

import 'theme.dart';

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
