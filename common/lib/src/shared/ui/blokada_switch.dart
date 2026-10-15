import 'package:common/src/shared/ui/haptics.dart';
import 'package:flutter/cupertino.dart';

/// The app's on/off switch: a [CupertinoSwitch] that gives a selection click
/// when the user flips it.
class BlokadaSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? activeColor;

  const BlokadaSwitch({super.key, required this.value, required this.onChanged, this.activeColor});

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    return CupertinoSwitch(
      value: value,
      activeTrackColor: activeColor,
      onChanged: onChanged == null
          ? null
          : (v) {
              Haptics.selection();
              onChanged(v);
            },
    );
  }
}
