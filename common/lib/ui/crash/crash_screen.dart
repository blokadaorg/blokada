import 'dart:async';
import 'dart:ui';

import 'package:common/service/I18nService.dart';
import 'package:common/ui/blur_background.dart';
import 'package:common/util/async.dart';
import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart';

import '../../stage/channel.pg.dart';
import '../../stage/stage.dart';
import '../../tracer/tracer.dart';
import '../../util/di.dart';
import '../../util/trace.dart';
import '../minicard/minicard.dart';
import '../theme.dart';

class CrashScreen extends StatefulWidget {
  const CrashScreen({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _CrashScreenState();
}

class _CrashScreenState extends State<CrashScreen>
    with TickerProviderStateMixin, TraceOrigin {
  final _stage = dep<StageStore>();
  final _tracer = dep<Tracer>();

  final _duration = const Duration(milliseconds: 200);

  GlobalKey<BlurBackgroundState> bgStateKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    autorun((_) {
      setState(() {
        // _isLocked = _lock.isLocked;
        // _hasPin = _lock.hasPin;
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  _close() async {
    traceAs("fromWidget", (trace) async {
      await _stage.setRoute(trace, StageKnownRoute.homeCloseOverlay.path);
    });
  }

  _shareLog() async {
    traceAs("fromWidget", (trace) async {
      await _tracer.shareLog(trace, forCrash: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<BlokadaTheme>()!;
    return BlurBackground(
      key: bgStateKey,
      onClosed: _close,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Spacer(),
            const SizedBox(height: 50),
            Icon(
              Icons.electric_bolt_outlined,
              size: 128,
              color: Colors.white.withOpacity(0.8),
            ),
            const SizedBox(height: 30),
            Text(
              "alert error header".i18n,
              style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Colors.white),
            ),
            const SizedBox(height: 70),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Text(
                "error unknown".i18n,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
            const SizedBox(height: 40),
            AnimatedOpacity(
              opacity: 1.0,
              duration: _duration,
              child: Column(
                children: [
                  MiniCard(
                    onTap: () {
                      bgStateKey.currentState?.animateToClose();
                      _shareLog();
                    },
                    color: theme.plus,
                    child: SizedBox(
                      width: 200,
                      child: Text("universal action share log".i18n,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            AnimatedOpacity(
              opacity: 1.0,
              duration: _duration,
              child: Row(
                children: [
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      bgStateKey.currentState?.animateToClose();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 64),
                      child: Text(
                        "universal action cancel".i18n,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
