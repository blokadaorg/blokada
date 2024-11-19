import 'dart:async';

import 'package:common/common/navigation.dart';
import 'package:common/common/widget/lock/circles.dart';
import 'package:common/common/widget/lock/keypad.dart';
import 'package:common/common/widget/overlay/blur_background.dart';
import 'package:common/core/core.dart';
import 'package:common/lock/lock.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:slide_to_act_reborn/slide_to_act_reborn.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen>
    with TickerProviderStateMixin, Logging, Disposables {
  final _stage = DI.get<StageStore>();

  final _lock = DI.get<LockActor>();
  final _isLocked = DI.get<IsLocked>();
  final _hasPin = DI.get<HasPin>();

  int _digitsEntered = 0;
  bool _showHeaderIcon = false;
  bool _dismissing = false;
  String? _pinEntered;
  String? _pinConfirmed;
  int _wrongAttempts = 0;

  final KeypadController _keypadCtrl = KeypadController();

  late final AnimationController _ctrlShake;
  late final Animation<Offset> _animShake;

  final GlobalKey<BlurBackgroundState> bgStateKey = GlobalKey();
  final GlobalKey<SlideActionState> _slideUnlockKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    disposeLater(_hasPin.onChange.listen(rebuild));
    disposeLater(_isLocked.onChange.listen(rebuild));

    _ctrlShake = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _ctrlShake.reset();
        }
      });
    disposeLater(_ctrlShake);

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
    _iconTimer?.cancel();
    disposeAll();
    super.dispose();
  }

  _checkPin(String pin) async {
    log(Markers.userTap).trace("tappedCheckPin", (m) async {
      setState(() {
        _showHeaderIcon = true;
      });

      try {
        if (pin != _pinConfirmed) throw Exception("Pin mismatch");

        if (_isLocked.now) {
          if (_wrongAttempts >= 3) {
            throw Exception("Too many wrong attempts");
          }

          await _lock.canUnlock(m, pin);
          await _unlock(pin);
        } else {
          await _lock.setLock(m, pin);
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
            _keypadCtrl.clear();
          });
        });

        if (_isLocked.now) {
          _incrementWrongAttempts();
        }
      }
    });
  }

  String _getHeaderString() {
    if (_wrongAttempts >= 3) {
      return "lock status too many attempts".i18n;
    } else if (_showHeaderIcon) {
      return "";
    } else if (_isLocked.now) {
      return "lock status locked".i18n;
    } else if (_pinEntered != null) {
      return "lock status enter to confirm".i18n;
    } else if (_hasPin.now) {
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
    log(Markers.userTap).trace("tappedClearLock", (m) async {
      _animateDismiss();
      await _lock.removeLock(m);
    });
  }

  _unlock(String pin) async {
    log(Markers.userTap).trace("tappedUnlock", (m) async {
      _animateDismiss();
      await _lock.unlock(m, pin);
    });
  }

  _cancel() async {
    log(Markers.userTap).trace("tappedCancel", (m) async {
      await _stage.dismissModal(m);
    });
  }

  _animateDismiss() {
    _dismissing = true;
    bgStateKey.currentState?.animateToClose();
  }

  _handleCancelDelete() {
    if (_digitsEntered > 0) {
      _keypadCtrl.delete();
    } else {
      _animateDismiss();
    }
  }

  _handlePinConfirm() async {
    await sleepAsync(const Duration(milliseconds: 100));
    _keypadCtrl.clear();
    _showHeaderIcon = false;
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
    return Material(
      type: MaterialType.transparency,
      child: BlurBackground(
        key: bgStateKey,
        //canClose: () => !_isLocked,
        onClosed: _cancel,
        child: Container(
          constraints: const BoxConstraints(maxWidth: maxContentWidth),
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
                        _isLocked.now
                            ? CupertinoIcons.lock_fill
                            : CupertinoIcons.lock_open,
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
                  controller: _keypadCtrl,
                  onPinEntered: (pin) {
                    setState(() {
                      if (_pinEntered == null) {
                        _pinEntered = pin;
                        if (!_isLocked.now) _handlePinConfirm();
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
                crossFadeState: _pinEntered != null && _isLocked.now
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
                          const Duration(seconds: 1),
                          () => _slideUnlockKey.currentState?.reset(),
                        );
                      },
                      outerColor: Colors.white.withOpacity(0.2),
                      innerColor: Colors.black.withOpacity(0.4),
                      borderRadius: 12,
                      elevation: 0,
                      text: "lock action slide unlock".i18n,
                      textStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                      sliderButtonIcon: const Icon(CupertinoIcons.chevron_right,
                          color: Colors.white),
                      submittedIcon: const Icon(CupertinoIcons.chevron_right,
                          color: Colors.white),
                      sliderRotate: false,
                    ),
                  ),
                ),
                secondChild: SizedBox(
                  height: 80,
                  child: Opacity(
                    opacity: /*_isLocked ? 0.0 :*/ 1.0,
                    child: _dismissing
                        ? Container()
                        : Row(
                            children: [
                              if (_hasPin.now && !_isLocked.now)
                                GestureDetector(
                                  onTap: _clear,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 64),
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
                              (_digitsEntered > 0)
                                  ? GestureDetector(
                                      onTap: _handleCancelDelete,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 64),
                                        child: Text(
                                          // (_digitsEntered > 0)
                                          //     ? "universal action delete".i18n
                                          //     : "universal action cancel".i18n,
                                          "universal action delete".i18n,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ),
                                    )
                                  : Container(),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }
}
