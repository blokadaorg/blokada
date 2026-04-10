import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Notifies the native side when Flutter has rendered its first frame, so
/// the native splash screen can be removed at the right moment instead of
/// relying on a fixed delay that is either too short (flash of blank screen)
/// or too long (unnecessary wait).
class StartupFirstFrameReporter extends StatefulWidget {
  final Widget child;

  const StartupFirstFrameReporter({
    super.key,
    required this.child,
  });

  @override
  State<StartupFirstFrameReporter> createState() => _StartupFirstFrameReporterState();
}

class _StartupFirstFrameReporterState extends State<StartupFirstFrameReporter> {
  @override
  void initState() {
    super.initState();
    StartupFirstFrameSignal.scheduleReport();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class StartupFirstFrameSignal {
  static const _channel = MethodChannel('org.blokada/startup');

  static bool _reportScheduled = false;
  static bool _reportSent = false;
  static Future<void>? _pendingReport;

  static void scheduleReport() {
    if (_reportSent || _reportScheduled) {
      return;
    }

    _reportScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingReport ??= _reportAfterFirstFrame();
    });
  }

  static Future<void> _reportAfterFirstFrame() async {
    try {
      await _channel.invokeMethod<void>('firstFrameRendered');
      _reportSent = true;
    } catch (_) {
      // The native side may not implement this bridge on every platform.
    } finally {
      _reportScheduled = false;
      _pendingReport = null;
    }
  }

  @visibleForTesting
  static void debugReset() {
    _reportScheduled = false;
    _reportSent = false;
    _pendingReport = null;
  }
}
