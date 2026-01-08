import 'package:countup/countup.dart';
import 'package:flutter/material.dart';

class MiniCardCounter extends StatefulWidget {
  final double counter;
  final double lastCounter;

  const MiniCardCounter({
    super.key,
    required this.counter,
    required this.lastCounter,
  });

  @override
  State<StatefulWidget> createState() => MiniCardCounterState();
}

class MiniCardCounterState extends State<MiniCardCounter> {
  @override
  Widget build(BuildContext context) {
    return Countup(
      begin: widget.lastCounter,
      end: widget.counter,
      duration: const Duration(seconds: 1),
      style: const TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
