import 'dart:ui';

import 'package:common/service/I18nService.dart';
import 'package:common/ui/overlay/blur_background.dart';
import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart';

import '../../common/widget.dart';
import '../../rate/rate.dart';
import '../../stage/stage.dart';
import '../../util/di.dart';
import '../../util/trace.dart';
import '../theme.dart';
import 'star.dart';

class RateScreen extends StatefulWidget {
  const RateScreen({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _RateScreenState();
}

class _RateScreenState extends State<RateScreen>
    with TickerProviderStateMixin, TraceOrigin {
  final _stage = dep<StageStore>();
  final _rate = dep<RateStore>();

  int _rating = 0;
  bool _showPlatformDialog = false;

  final _duration = const Duration(milliseconds: 200);

  late final AnimationController _ctrlShake;
  late final Animation<Offset> _animShake;

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

    _ctrlShake = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _ctrlShake.reset();
        }
      });

    _animShake = TweenSequence(
      <TweenSequenceItem<Offset>>[
        TweenSequenceItem<Offset>(
          tween: Tween<Offset>(
            begin: Offset.zero,
            end: const Offset(0.03, 0.0),
          )..chain(CurveTween(curve: Curves.linear)),
          weight: 1.0,
        ),
        TweenSequenceItem<Offset>(
          tween: Tween<Offset>(
            begin: const Offset(0.03, 0.0),
            end: const Offset(-0.03, 0.0),
          )..chain(CurveTween(curve: Curves.linear)),
          weight: 2.0,
        ),
        TweenSequenceItem<Offset>(
          tween: Tween<Offset>(
            begin: const Offset(-0.05, 0.0),
            end: Offset.zero,
          )..chain(CurveTween(curve: Curves.linear)),
          weight: 1.0,
        ),
      ],
    ).animate(CurvedAnimation(
      parent: _ctrlShake,
      curve: Curves.linear,
    ));
  }

  @override
  void dispose() {
    _ctrlShake.dispose();
    super.dispose();
  }

  _close() async {
    traceAs("tappedCloseRateScreen", (trace) async {
      await _stage.dismissModal(trace);
      await _rate.rate(trace, _rating, _showPlatformDialog);
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
              Image.asset(
                "assets/images/blokada_logo.png",
                fit: BoxFit.cover,
                width: 128,
                height: 128,
                // color: Colors.white.withOpacity(0.8),
              ),
              const SizedBox(height: 30),
              Text(
                "main rate us header".i18n,
                style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: Colors.white),
              ),
              const SizedBox(height: 30),
              Text(
                "main rate us description".i18n,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RateStar(
                    full: _rating >= 1,
                    onTap: () => setState(() => _rating = 1),
                  ),
                  RateStar(
                    full: _rating >= 2,
                    onTap: () => setState(() => _rating = 2),
                  ),
                  RateStar(
                    full: _rating >= 3,
                    onTap: () => setState(() => _rating = 3),
                  ),
                  RateStar(
                    full: _rating >= 4,
                    onTap: () => setState(() => _rating = 4),
                  ),
                  RateStar(
                    full: _rating >= 5,
                    onTap: () => setState(() => _rating = 5),
                  ),
                ],
              ),
              const SizedBox(height: 80),
              AnimatedOpacity(
                opacity: _rating > 0 ? 1.0 : 0.0,
                duration: _duration,
                child: Column(
                  children: [
                    AnimatedOpacity(
                      opacity: _rating >= 4 ? 1.0 : 0.0,
                      duration: _duration,
                      child: Text(
                        "main rate us on app store".i18n,
                        textAlign: TextAlign.center,
                        style:
                            const TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 20),
                    MiniCard(
                      onTap: () {
                        _showPlatformDialog = true;
                        bgStateKey.currentState?.animateToClose();
                      },
                      color: theme.accent,
                      child: SizedBox(
                        width: 200,
                        child: Text(
                            _rating >= 4
                                ? "main rate us action sure".i18n
                                : "universal action continue".i18n,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedOpacity(
                opacity: _rating > 0 && _rating < 4 ? 0.0 : 1.0,
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
