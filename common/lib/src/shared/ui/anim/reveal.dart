import 'dart:async';

import 'package:common/src/shared/ui/motion.dart';
import 'package:flutter/material.dart';

/// Brings a card in by fading it up 12 px over 350 ms, eased out, each
/// [index] starting 60 ms after the one before, so a stack of cards arrives
/// as a short cascade (#460, motion spec from #468). With Reduce Motion on it
/// is a plain fade. Going out it fades without the stagger.
///
/// The older Home slides cards in from five screen widths away over a second
/// (`Sliding`); this is the calmer replacement for the redesigned cards.
class Reveal extends StatefulWidget {
  static const duration = Duration(milliseconds: 350);
  static const stagger = Duration(milliseconds: 60);
  static const rise = 12.0;

  final bool visible;
  final int index;
  final Widget child;

  const Reveal({super.key, required this.visible, this.index = 0, required this.child});

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(vsync: this, duration: Reveal.duration);
  late final _curve = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  Timer? _delay;

  @override
  void initState() {
    super.initState();
    if (widget.visible) _show();
  }

  @override
  void didUpdateWidget(covariant Reveal old) {
    super.didUpdateWidget(old);
    if (widget.visible == old.visible) return;
    if (widget.visible) {
      _show();
    } else {
      _delay?.cancel();
      _ctrl.reverse();
    }
  }

  void _show() {
    _delay?.cancel();
    final delay = Reveal.stagger * widget.index;
    if (delay == Duration.zero) {
      _ctrl.forward();
      return;
    }
    // Cancelled when hidden again or disposed while waiting.
    _delay = Timer(delay, _ctrl.forward);
  }

  @override
  void dispose() {
    _delay?.cancel();
    _curve.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    return IgnorePointer(
      ignoring: !widget.visible,
      child: AnimatedBuilder(
        animation: _curve,
        child: widget.child,
        builder: (context, child) {
          final value = _curve.value;
          final faded = Opacity(opacity: value, child: child);
          if (reduced) return faded;
          return Transform.translate(offset: Offset(0, Reveal.rise * (1 - value)), child: faded);
        },
      ),
    );
  }
}
