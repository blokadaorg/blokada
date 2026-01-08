import 'package:flutter/material.dart';

class UnreadBadge extends StatelessWidget {
  final String label;

  const UnreadBadge({super.key, this.label = "1"});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(32),
      ),
      child: SizedBox(
        width: 18,
        height: 18,
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
