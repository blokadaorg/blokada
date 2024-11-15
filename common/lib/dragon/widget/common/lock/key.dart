import 'package:common/common/widget/touch.dart';
import 'package:common/dragon/widget/common/lock/keypad.dart';
import 'package:flutter/material.dart';

class LockScreenKey extends StatefulWidget {
  final String digit;
  final String letters;
  final StringCallback? onTap;

  const LockScreenKey({
    super.key,
    required this.digit,
    this.letters = '',
    this.onTap,
  });

  @override
  State<StatefulWidget> createState() => LockScreenKeyState();
}

class LockScreenKeyState extends State<LockScreenKey> {
  @override
  Widget build(BuildContext context) {
    return Touch(
      onTap: () => widget.onTap?.call(widget.digit),
      maxValue: 0.4,
      decorationBuilder: (value) {
        return BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.2 + value),
        );
      },
      child: SizedBox(
        height: 80,
        width: 80,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              widget.digit,
              style: const TextStyle(
                fontSize: 32.0,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (widget.letters.isNotEmpty)
              Text(
                widget.letters,
                style: const TextStyle(
                  fontSize: 10.0,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
