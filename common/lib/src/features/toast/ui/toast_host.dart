import 'dart:async';

import 'package:common/src/core/core.dart';
import 'package:common/src/features/toast/domain/toast.dart';
import 'package:flutter/material.dart';

/// Shows the current [ToastMessage] as a pill near the bottom of the screen.
///
/// Wraps the app's root navigator (MaterialApp.builder), so toasts appear
/// above sheets and dialogs. It never takes taps.
class ToastHost extends StatefulWidget {
  final Widget child;

  const ToastHost({super.key, required this.child});

  static const visibleFor = Duration(seconds: 2);
  static const errorVisibleFor = Duration(seconds: 3);

  @override
  State<ToastHost> createState() => _ToastHostState();
}

class _ToastHostState extends State<ToastHost> {
  final _value = Core.get<ToastValue>();

  StreamSubscription<ValueUpdate<ToastMessage?>>? _sub;
  Timer? _hideTimer;
  ToastMessage? _message;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _sub = _value.onChange.listen((update) => _show(update.now));
  }

  void _show(ToastMessage? message) {
    if (message == null || !mounted) return;
    _hideTimer?.cancel();
    final wasShowing = _message != null;
    setState(() {
      _message = message;
      // A new pill first builds hidden, so it animates in on the next frame.
      _visible = wasShowing;
    });
    if (!wasShowing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _message == message) setState(() => _visible = true);
      });
    }
    _hideTimer = Timer(message.isError ? ToastHost.errorVisibleFor : ToastHost.visibleFor, () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = _message;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final bottom = MediaQuery.viewPaddingOf(context).bottom + 32;

    return Stack(
      children: [
        widget.child,
        if (message != null)
          Positioned(
            left: 24,
            right: 24,
            bottom: bottom,
            child: IgnorePointer(
              child: AnimatedSlide(
                offset: _visible || reduceMotion ? Offset.zero : const Offset(0, 0.4),
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: AnimatedOpacity(
                  opacity: _visible ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  // Drop the hidden pill so screen readers don't find it.
                  onEnd: () {
                    if (!_visible && mounted) setState(() => _message = null);
                  },
                  child: Center(child: _ToastPill(message: message)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ToastPill extends StatelessWidget {
  final ToastMessage message;

  const _ToastPill({required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = message.isError ? scheme.errorContainer : scheme.inverseSurface;
    final foreground = message.isError ? scheme.onErrorContainer : scheme.onInverseSurface;

    return Semantics(
      liveRegion: true,
      child: Material(
        color: background,
        elevation: 6,
        shape: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message.isError) ...[
                Icon(Icons.error_outline, size: 20, color: foreground),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  message.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: foreground, fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
