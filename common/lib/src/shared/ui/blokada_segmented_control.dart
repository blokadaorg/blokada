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
      // Segments split the width evenly; a short label too wide for its share
      // at large text sizes shrinks to fit instead of overflowing.
      children: children.map(
        (value, child) => MapEntry(value, FittedBox(fit: BoxFit.scaleDown, child: child)),
      ),
    );
  }
}
