import 'package:common/common/widget/theme.dart';
import 'package:flutter/material.dart';

class ActionInfo extends StatelessWidget {
  final String label;
  final String text;

  const ActionInfo({super.key, required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: context.theme.textSecondary)),
          Text(text, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}
