import 'package:common/core/core.dart';
import 'package:flutter/material.dart';

const _tabBarHeight = 80.0;

class TapBarCompensation extends StatefulWidget {
  const TapBarCompensation({Key? key}) : super(key: key);

  @override
  State<TapBarCompensation> createState() => _TapBarCompensationState();
}

class _TapBarCompensationState extends State<TapBarCompensation> {
  @override
  Widget build(BuildContext context) {
    if (Core.act.isFamily) return const SizedBox.shrink();
    return SizedBox(height: context.isKeyboardOpened ? 0 : _tabBarHeight);
  }
}

extension BuildContextExt on BuildContext {
  double get tabBarHeight => Core.act.isFamily ? 0 : _tabBarHeight;
  bool get isKeyboardOpened => MediaQuery.of(this).viewInsets.bottom > 0;
}
