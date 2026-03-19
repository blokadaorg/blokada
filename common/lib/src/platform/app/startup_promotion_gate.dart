import 'dart:async';

import 'package:common/src/core/core.dart';
import 'package:common/src/platform/app/launch_context.dart';
import 'package:flutter/material.dart';

class StartupPromotionGate extends StatefulWidget {
  static const placeholderKey = Key('startup-promotion-placeholder');

  final AppLaunchContext launchContext;
  final Future<void> Function(Marker m) startForeground;
  final Widget child;

  const StartupPromotionGate({
    super.key,
    required this.launchContext,
    required this.startForeground,
    required this.child,
  });

  @override
  State<StartupPromotionGate> createState() => _StartupPromotionGateState();
}

class _StartupPromotionGateState extends State<StartupPromotionGate>
    with WidgetsBindingObserver, Logging {
  late bool _ready = widget.launchContext.allowRunApp;
  bool _promotionStarted = false;

  @override
  void initState() {
    super.initState();

    if (_ready) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startForegroundAfterMount());
      return;
    }

    WidgetsBinding.instance.addObserver(this);
    _promoteIfResumed();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _promote();
    }
  }

  void _promoteIfResumed() {
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      _promote();
    }
  }

  Future<void> _startForegroundAfterMount() async {
    try {
      await widget.startForeground(Markers.start);
    } catch (e, s) {
      log(Markers.start).e(msg: "foreground startup failed after mount", err: e, stack: s);
    }
  }

  Future<void> _promote() async {
    if (_ready || _promotionStarted) {
      return;
    }

    _promotionStarted = true;
    var promotionCompleted = false;

    try {
      await widget.startForeground(Markers.start);
      promotionCompleted = true;

      if (!mounted) {
        return;
      }

      setState(() {
        _ready = true;
      });
    } finally {
      if (!promotionCompleted) {
        _promotionStarted = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) {
      return widget.child;
    }

    return const ColoredBox(
      key: StartupPromotionGate.placeholderKey,
      color: Colors.transparent,
      child: SizedBox.expand(),
    );
  }
}
