import 'package:common/src/core/core.dart';
import 'package:flutter/material.dart';

const _tabBarHeight = 80.0;

class TabBarCompensation extends StatefulWidget {
  const TabBarCompensation({Key? key}) : super(key: key);

  @override
  State<TabBarCompensation> createState() => _TabBarCompensationState();
}

class _TabBarCompensationState extends State<TabBarCompensation> with Logging {
  @override
  Widget build(BuildContext context) {
    log(Markers.root).t(
        "rebuild TapBarCompensation, isKeyboardOpened: ${context.isKeyboardOpened}");
    if (Core.act.isFamily) return const SizedBox.shrink();
    return SizedBox(height: context.isKeyboardOpened ? 0 : _tabBarHeight);
  }
}

extension BuildContextExt on BuildContext {
  double get tabBarHeightKbDependent =>
      Core.act.isFamily ? 0 : (isKeyboardOpened ? 0 : _tabBarHeight);
  //bool get isKeyboardOpened => MediaQuery.of(this).viewInsets.bottom > 0;
  bool get isKeyboardOpened => false; // TODO: make sure it works
}
