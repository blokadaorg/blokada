import 'dart:async';
import 'dart:ui';

import 'package:common/service/I18nService.dart';
import 'package:common/ui/blur_background.dart';
import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart';

import '../../lock/lock.dart';
import '../../stage/channel.pg.dart';
import '../../stage/stage.dart';
import '../../util/di.dart';
import '../../util/trace.dart';
import 'circles.dart';
import 'keypad.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen>
    with TickerProviderStateMixin, TraceOrigin {
  final _stage = dep<StageStore>();
  final _lock = dep<LockStore>();

  int _digitsEntered = 0;
  bool _isLocked = false;
  bool _hasPin = false;
  bool _showHeaderIcon = false;

  late final AnimationController _ctrlShake;
  late final Animation<Offset> _animShake;

  GlobalKey<BlurBackgroundState> bgStateKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    autorun((_) {
      setState(() {
        _isLocked = _lock.isLocked;
        _hasPin = _lock.hasPin;
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

    _showHeaderTextForShortWhile();
  }

  @override
  void dispose() {
    _ctrlShake.dispose();
    _timer?.cancel();
    super.dispose();
  }

  _checkPin(String pin) async {
    traceAs("fromWidget", (trace) async {
      try {
        if (_lock.isLocked) {
          await _lock.unlock(trace, pin);
          bgStateKey.currentState?.animateToClose();
        } else {
          await _lock.lock(trace, pin);
          _digitsEntered = 0;
          _showHeaderTextForShortWhile();
        }
      } catch (e) {
        _showHeaderTextForShortWhile();
        _ctrlShake.forward();

        Future.delayed(const Duration(milliseconds: 500), () {
          setState(() {
            _digitsEntered = 0;
          });
        });
      }
    });
  }

  String _getHeaderString() {
    if (_isLocked) {
      return "lock status locked".i18n;
    } else if (_hasPin) {
      return "lock status unlocked has pin".i18n;
    } else {
      return "lock status unlocked".i18n;
    }
  }

  Timer? _timer;
  _showHeaderTextForShortWhile() {
    _timer?.cancel();
    setState(() {
      _showHeaderIcon = false;
    });

    // Replace the header text with the lock icon after short while
    _timer = Timer(const Duration(seconds: 5), () {
      setState(() {
        _showHeaderIcon = true;
      });
    });
  }

  _clear() async {
    traceAs("fromWidget", (trace) async {
      await _lock.removeLock(trace);
      bgStateKey.currentState?.animateToClose();
    });
  }

  _unlock() async {
    traceAs("fromWidget", (trace) async {
      await _stage.setRoute(trace, StageKnownRoute.homeCloseOverlay.path);
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlurBackground(
      key: bgStateKey,
      canClose: () => !_isLocked,
      onClosed: _unlock,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Spacer(),
          SizedBox(
            height: 64,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: AnimatedCrossFade(
                firstChild: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _hasPin ? Icons.lock : Icons.lock_open,
                      color: Colors.white,
                      size: 48,
                    ),
                  ],
                ),
                secondChild: Text(_getHeaderString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      // fontWeight: FontWeight.w500,
                    )),
                crossFadeState: _showHeaderIcon
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                duration: const Duration(milliseconds: 300),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SlideTransition(
              position: _animShake,
              child: Circles(amount: 4, filled: _digitsEntered),
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: 300,
            child: KeyPad(
              pinLength: 4,
              onPinEntered: _checkPin,
              onDigitEntered: (digits) => setState(() {
                _digitsEntered = digits;
              }),
            ),
          ),
          const Spacer(),
          Opacity(
            opacity: _isLocked ? 0.0 : 1.0,
            child: Row(
              children: [
                if (_hasPin)
                  GestureDetector(
                    onTap: _clear,
                    child: Padding(
                      padding: const EdgeInsets.all(64),
                      child: Text(
                        "universal action clear".i18n,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    bgStateKey.currentState?.animateToClose();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(64),
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
    );
  }
}
