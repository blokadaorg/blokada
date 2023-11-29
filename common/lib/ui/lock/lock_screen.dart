import 'dart:async';
import 'dart:ui';

import 'package:common/service/I18nService.dart';
import 'package:common/ui/overlay/blur_background.dart';
import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart';
import 'package:slide_to_act_reborn/slide_to_act_reborn.dart';

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
  String? _pinEntered;
  String? _pinConfirmed;
  int _wrongAttempts = 0;

  late final AnimationController _ctrlShake;
  late final Animation<Offset> _animShake;

  final GlobalKey<BlurBackgroundState> bgStateKey = GlobalKey();
  final GlobalKey<SlideActionState> _slideUnlockKey = GlobalKey();

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
    _iconTimer?.cancel();
    super.dispose();
  }

  _checkPin(String pin) async {
    traceAs("tappedCheckPin", (trace) async {
      setState(() {
        _showHeaderIcon = true;
      });

      try {
        if (pin != _pinConfirmed) throw Exception("Pin mismatch");

        if (_lock.isLocked) {
          if (_wrongAttempts >= 3) {
            throw Exception("Too many wrong attempts");
          }

          await _lock.canUnlock(trace, pin);
          await _unlock(pin);
        } else {
          await _lock.lock(trace, pin);
          setState(() {
            _digitsEntered = 0;
            _pinEntered = null;
            _pinConfirmed = null;
          });
          _animateDismiss();
        }
      } catch (e) {
        _showHeaderTextForShortWhile();
        _ctrlShake.forward();

        Future.delayed(const Duration(milliseconds: 500), () {
          setState(() {
            _digitsEntered = 0;
            _pinEntered = null;
            _pinConfirmed = null;
          });
        });

        if (_isLocked) {
          _incrementWrongAttempts();
        }
      }
    });
  }

  String _getHeaderString() {
    if (_wrongAttempts >= 3) {
      return "Too many wrong attempts. Try again later.";
    } else if (_showHeaderIcon) {
      return "";
    } else if (_isLocked) {
      return "lock status locked".i18n;
    } else if (_pinEntered != null) {
      return "Enter the pin code again to confirm";
    } else if (_hasPin) {
      return "lock status unlocked has pin".i18n;
    } else {
      return "lock status unlocked".i18n;
    }
  }

  Timer? _iconTimer;
  _showHeaderTextForShortWhile() {
    _iconTimer?.cancel();
    setState(() {
      _showHeaderIcon = false;
    });

    // Replace the header text with the lock icon after short while
    _iconTimer = Timer(const Duration(seconds: 5), () {
      setState(() {
        _showHeaderIcon = true;
      });
    });
  }

  _clear() async {
    traceAs("tappedClearLock", (trace) async {
      _animateDismiss();
      await _lock.removeLock(trace);
    });
  }

  _unlock(String pin) async {
    traceAs("tappedUnlock", (trace) async {
      _animateDismiss();
      await _lock.unlock(trace, pin);
    });
  }

  _cancel() async {
    traceAs("tappedCancel", (trace) async {
      await _stage.dismissModal(trace);
    });
  }

  _animateDismiss() {
    bgStateKey.currentState?.animateToClose();
  }

  Timer? _wrongAttemptsTimer;
  _incrementWrongAttempts() {
    _wrongAttemptsTimer?.cancel();
    setState(() {
      _wrongAttempts++;
    });

    if (_wrongAttempts >= 3) {
      _wrongAttemptsTimer = Timer(const Duration(seconds: 15), () {
        setState(() {
          _wrongAttempts = 0;
          _showHeaderIcon = false;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlurBackground(
      key: bgStateKey,
      //canClose: () => !_isLocked,
      onClosed: _cancel,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Spacer(),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: AnimatedCrossFade(
              firstChild: SizedBox(
                height: 112,
                child: Center(
                  child: Icon(
                    _hasPin ? Icons.lock : Icons.lock_open,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
              secondChild: SizedBox(
                height: 112,
                child: Center(
                  child: Text(_getHeaderString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        // fontWeight: FontWeight.w500,
                      )),
                ),
              ),
              crossFadeState: _showHeaderIcon
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 300),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(7.0),
            child: SlideTransition(
              position: _animShake,
              child: Circles(amount: 4, filled: _digitsEntered),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: 300,
            child: KeyPad(
              pinLength: 4,
              onPinEntered: (pin) {
                setState(() {
                  if (_pinEntered == null) {
                    _pinEntered = pin;
                  } else {
                    _pinConfirmed = pin;
                    _checkPin(_pinEntered ?? "");
                  }
                });
              },
              onDigitEntered: (digits) => setState(() {
                _digitsEntered = digits;
                if (_pinConfirmed != null) {
                  _pinConfirmed = null;
                  _pinEntered = null;
                }
              }),
            ),
          ),
          const Spacer(),
          AnimatedCrossFade(
            crossFadeState: _pinEntered != null && _isLocked
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 300),
            firstChild: SizedBox(
              height: 80,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: SlideAction(
                  key: _slideUnlockKey,
                  onSubmit: () {
                    setState(() {
                      _pinConfirmed = _pinEntered;
                    });
                    _checkPin(_pinEntered ?? "");
                    Future.delayed(
                      Duration(seconds: 1),
                      () => _slideUnlockKey.currentState?.reset(),
                    );
                  },
                  outerColor: Colors.white.withOpacity(0.2),
                  innerColor: Colors.black.withOpacity(0.4),
                  borderRadius: 12,
                  elevation: 0,
                  text: "Slide to unlock",
                  textStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                  sliderButtonIcon:
                      Icon(Icons.arrow_forward_ios, color: Colors.white),
                  submittedIcon: Icon(Icons.lock, color: Colors.white),
                  sliderRotate: false,
                ),
              ),
            ),
            secondChild: SizedBox(
              height: 80,
              child: Opacity(
                opacity: /*_isLocked ? 0.0 :*/ 1.0,
                child: Row(
                  children: [
                    if (_hasPin && !_isLocked)
                      GestureDetector(
                        onTap: _clear,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 64),
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
                        _animateDismiss();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 64),
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
            ),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}
