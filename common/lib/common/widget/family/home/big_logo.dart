import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:vistraced/via.dart';

import '../../../model.dart';
import '../../../../family/devices.dart';
import '../../../../ui/debug/commanddialog.dart';
import '../../../../util/trace.dart';

part 'big_logo.g.dart';

class BigLogo extends StatefulWidget {
  const BigLogo({Key? key}) : super(key: key);

  @override
  State<BigLogo> createState() => _$BigLogoState();
}

@Injected(onlyVia: true, immediate: true)
class BigLogoState extends State<BigLogo>
    with TickerProviderStateMixin, Traceable, TraceOrigin {
  late final _phase = Via.as<FamilyPhase>()..also(rebuild);
  late final _devices = Via.as<FamilyDevices>()..also(rebuild);

  late AnimationController _bounceController;
  late AnimationController _spinController;

  late Animation<double> _bounceAnimation;
  late Animation<double> _spinAnimation;

  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

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

    _scaleAnimation = Tween<double>(begin: 1, end: 0.7).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));

    _phase.fetch();
    _devices.fetch();
  }

  rebuild() {
    setState(() {
      spinImage();
      _updateLogoScale();
    });
  }

  _updateLogoScale() async {
    if (!_phase.now.isLocked() && _devices.now.entries.length > 1) {
      _scaleController.forward();
    } else {
      _scaleController.reverse();
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _spinController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    //if (!_phase.isLocked()) {
                    _showCommandDialog(context);
                    //}
                  },
                  onDoubleTap: () {
                    // if (!_phase.now.isLocked()) {
                    _showCommandDialog(context);
                    // }
                  },
                  child: Stack(
                    children: [
                      Transform.translate(
                        offset: const Offset(5, 15),
                        child: Image.asset(
                          "assets/images/family-logo.png",
                          width: 160,
                          fit: BoxFit.contain,
                          //height: 600,
                          //filterQuality: FilterQuality.high,
                          color: Colors.black.withOpacity(0.05),
                        ),
                      ),
                      Image.asset(
                        "assets/images/family-logo.png",
                        width: 160,
                        fit: BoxFit.contain,
                        //height: 600,
                        //filterQuality: FilterQuality.high,
                        //color: Colors.white,
                      ),
                    ],
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
