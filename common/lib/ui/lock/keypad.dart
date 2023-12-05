import 'package:flutter/material.dart';

import 'key.dart';

typedef StringCallback = void Function(String value);
typedef IntCallback = void Function(int value);

class KeypadController {
  Function _delete = () {};
  Function _clear = () {};

  void delete() {
    _delete.call();
  }

  void clear() {
    _clear.call();
  }

  void _setDelete(Function delete) {
    _delete = delete;
  }

  void _setClear(Function clear) {
    _clear = clear;
  }
}

class KeyPad extends StatefulWidget {
  final int pinLength;
  final KeypadController controller;
  final StringCallback onPinEntered;
  final IntCallback? onDigitEntered;

  const KeyPad({
    super.key,
    required this.controller,
    required this.pinLength,
    required this.onPinEntered,
    this.onDigitEntered,
  });

  @override
  State<StatefulWidget> createState() => _KeyPadState();
}

class _KeyPadState extends State<KeyPad> {
  String _pin = '';

  @override
  void initState() {
    super.initState();
    widget.controller._setDelete(delete);
    widget.controller._setClear(clear);
  }

  _onKeyTap(String digit) {
    if (_pin.length == widget.pinLength) return;
    _pin += digit;
    widget.onDigitEntered?.call(_pin.length);
    if (_pin.length == widget.pinLength) {
      widget.onPinEntered(_pin);
    }
  }

  void delete() {
    setState(() {
      if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
      widget.onDigitEntered?.call(_pin.length);
    });
  }

  void clear() {
    setState(() {
      _pin = '';
      widget.onDigitEntered?.call(_pin.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              LockScreenKey(digit: '1', letters: ' ', onTap: _onKeyTap),
              const SizedBox(width: 4.0),
              LockScreenKey(digit: '2', letters: 'A B C', onTap: _onKeyTap),
              const SizedBox(width: 4.0),
              LockScreenKey(digit: '3', letters: 'D E F', onTap: _onKeyTap),
            ],
          ),
          const SizedBox(height: 20.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              LockScreenKey(digit: '4', letters: 'G H I', onTap: _onKeyTap),
              const SizedBox(width: 4.0),
              LockScreenKey(digit: '5', letters: 'J K L', onTap: _onKeyTap),
              const SizedBox(width: 4.0),
              LockScreenKey(digit: '6', letters: 'M N O', onTap: _onKeyTap),
            ],
          ),
          const SizedBox(height: 20.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              LockScreenKey(digit: '7', letters: 'P Q R S', onTap: _onKeyTap),
              const SizedBox(width: 4.0),
              LockScreenKey(digit: '8', letters: 'T U V', onTap: _onKeyTap),
              const SizedBox(width: 4.0),
              LockScreenKey(digit: '9', letters: 'W X Y Z', onTap: _onKeyTap),
            ],
          ),
          const SizedBox(height: 20.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              LockScreenKey(digit: '0', letters: '', onTap: _onKeyTap),
            ],
          ),
        ],
      ),
    );
  }
}
