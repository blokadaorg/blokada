import 'dart:async';

import 'package:common/src/core/core.dart';
import 'package:common/src/platform/app/launch_context.dart';
import 'package:flutter/material.dart';

class StartupPromotionGate extends StatefulWidget {
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
  static const _visibleUiFallbackDelay = Duration(seconds: 1);

  bool _promotionStarted = false;
  Timer? _visibleUiFallbackTimer;

  @override
  void initState() {
    super.initState();

    if (widget.launchContext.allowRunApp) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startForegroundAfterMount());
      return;
    }

    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncVisibleFallbackAndPromote());
    _visibleUiFallbackTimer = Timer(
      _visibleUiFallbackDelay,
      _syncVisibleFallbackAndPromote,
    );
  }

  @override
  void dispose() {
    _visibleUiFallbackTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _syncVisibleFallbackAndPromote();
  }

  void _syncVisibleFallbackAndPromote() {
    if (_isUiVisibleState(WidgetsBinding.instance.lifecycleState)) {
      _promote();
    }
  }

  bool _isUiVisibleState(AppLifecycleState? state) {
    return state == AppLifecycleState.resumed || state == AppLifecycleState.inactive;
  }

  Future<void> _startForegroundAfterMount() async {
    try {
      await widget.startForeground(Markers.start);
    } catch (e, s) {
      log(Markers.start).e(msg: "foreground startup failed after mount", err: e, stack: s);
    }
  }

  Future<void> _promote() async {
    if (widget.launchContext.allowRunApp || _promotionStarted) {
      return;
    }

    _promotionStarted = true;

    try {
      await widget.startForeground(Markers.start);
    } finally {
      _promotionStarted = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
