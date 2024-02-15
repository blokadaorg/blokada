import 'dart:ui';

import 'package:common/service/I18nService.dart';
import 'package:common/ui/overlay/blur_background.dart';
import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart';

import '../../common/widget.dart';
import '../../stage/stage.dart';
import '../../tracer/tracer.dart';
import '../../util/di.dart';
import '../../util/trace.dart';
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
    traceAs("tappedCloseCrashScreen", (trace) async {
      await _stage.dismissModal(trace);
    });
  }

  _shareLog() async {
    traceAs("tappedShareCrashLog", (trace) async {
      await _tracer.shareLog(trace, forCrash: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<BlokadaTheme>()!;
    return BlurBackground(
      key: bgStateKey,
      onClosed: _close,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
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
                  "crash body".i18n,
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
                      color: theme.accent,
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
      ),
    );
  }
}
