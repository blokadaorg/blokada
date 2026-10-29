import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/material.dart';

class SectionLabel extends StatelessWidget {
  final String text;

  const SectionLabel({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(text,
            style: context.theme.text.callout.copyWith(
                fontWeight: FontWeight.w400, color: context.theme.textSecondary)),
      ),
    );
  }
}
