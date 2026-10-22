import 'package:common/src/shared/ui/motion.dart';
import 'package:flutter/widgets.dart';

/// Crossfades [child] whenever [switchKey] changes, like a list switching
/// between tabs or ranges, so the content does not swap in one frame. The
/// height follows the new content smoothly; with Reduce Motion it is a plain
/// fade and the height changes at once.
class Crossfade extends StatelessWidget {
  static const duration = Duration(milliseconds: 150);

  final Object switchKey;
  final Widget child;

  const Crossfade({super.key, required this.switchKey, required this.child});

  @override
  Widget build(BuildContext context) {
    final switcher = AnimatedSwitcher(
      duration: duration,
      // Top-aligned, so a shorter list does not float in the middle while
      // the taller one fades out.
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        // build_runner's parser predates null-aware elements.
        // ignore: use_null_aware_elements
        children: [...previous, if (current != null) current],
      ),
      child: KeyedSubtree(key: ValueKey(switchKey), child: child),
    );
    if (Motion.reduced(context)) return switcher;
    return AnimatedSize(
      duration: duration,
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: switcher,
    );
  }
}
