import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:mobx/mobx.dart';

import '../../account/account.dart';
import '../../lock/lock.dart';
import '../../onboard/onboard.dart';
import '../../util/di.dart';
import '../../util/trace.dart';
import '../debug/commanddialog.dart';

class BigLogo extends StatefulWidget {
  const BigLogo({Key? key}) : super(key: key);

  @override
  State<BigLogo> createState() => BigLogoState();
}

class BigLogoState extends State<BigLogo>
    with TickerProviderStateMixin, Traceable, TraceOrigin {
  final _onboard = dep<OnboardStore>();
  final _lock = dep<LockStore>();
  final _account = dep<AccountStore>();

  late AnimationController _bounceController;
  late AnimationController _spinController;

  late Animation<double> _bounceAnimation;
  late Animation<double> _spinAnimation;

  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  var _locked = true;

  @override
  void initState() {
    super.initState();

    _bounceController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _bounceController.repeat(reverse: true);

    _bounceAnimation = Tween<double>(begin: 0, end: 15).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.easeInOut,
    ));

    // For spin animation
    _spinController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _spinAnimation =
        Tween<double>(begin: 0, end: 2 * 3.14).animate(CurvedAnimation(
      parent: _spinController,
      curve: Curves.easeInOut,
    ));

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1, end: 0.5).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));

    autorun((_) {
      if (_onboard.onboardState == OnboardState.completed &&
          !_lock.isLocked &&
          _account.type.isActive()) {
        _scaleController.forward();
      } else if (_lock.isLocked ||
          _onboard.onboardState != OnboardState.completed ||
          !_account.type.isActive()) {
        _scaleController.reverse();
      }
    });

    autorun((_) {
      setState(() {
        _locked = _lock.isLocked;
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
    _bounceController.dispose();
    _spinController.dispose();
    _scaleController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    spinImage();
    return AnimatedBuilder(
      animation: foundation.Listenable.merge(
          [_bounceController, _spinController, _scaleController]),
      builder: (context, child) {
        return Positioned(
          top: _bounceAnimation.value,
          child: Padding(
            padding: const EdgeInsets.only(left: 64.0, right: 64, top: 90),
            child: Transform.scale(
              scale: _scaleAnimation.value,
              alignment: Alignment.topCenter,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001) // Perspective
                  ..rotateY(_spinAnimation.value),
                child: GestureDetector(
                  onTap: () {
                    spinImage();
                  },
                  onHorizontalDragEnd: (_) {
                    if (!_locked) {
                      _showCommandDialog(context);
                    }
                  },
                  child: Image.asset(
                    "assets/images/family-logo.png",
                    width: 256,
                    //height: 600,
                    //filterQuality: FilterQuality.high,
                    fit: BoxFit.contain,
                    //color: Colors.black.withOpacity(0.1),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void spinImage() {
    _spinController.forward().then((_) {
      _spinController.reset();
    });
  }

  Future<void> _showCommandDialog(BuildContext context) {
    return showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return const CommandDialog();
        });
  }
}
