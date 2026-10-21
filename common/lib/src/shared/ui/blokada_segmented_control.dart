import 'package:common/src/shared/ui/haptics.dart';
import 'package:flutter/cupertino.dart';

/// The app's segmented control: a [CupertinoSlidingSegmentedControl] that
/// gives a selection click when the user picks another segment.
class BlokadaSegmentedControl<T extends Object> extends StatelessWidget {
  final T? groupValue;
  final ValueChanged<T?> onValueChanged;
  final Map<T, Widget> children;

  const BlokadaSegmentedControl({
    super.key,
    required this.groupValue,
    required this.onValueChanged,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoSlidingSegmentedControl<T>(
      groupValue: groupValue,
      onValueChanged: (v) {
        if (v != groupValue) Haptics.selection();
        onValueChanged(v);
      },
      children: children,
    );
  }
}
