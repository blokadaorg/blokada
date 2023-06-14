import 'package:flutter/material.dart';

class Circles extends StatelessWidget {
  final int amount;
  final int filled;

  const Circles({
    super.key,
    required this.amount,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        amount,
        (index) => Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(
            index < filled ? Icons.circle : Icons.circle_outlined,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }
}
