import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/core/core.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';

class BigIcon extends StatefulWidget {
  final IconData? icon;
  final bool canShowLogo;

  const BigIcon({Key? key, required this.icon, required this.canShowLogo})
      : super(key: key);

  @override
  State<BigIcon> createState() => BigIconState();
}

class BigIconState extends State<BigIcon> with TickerProviderStateMixin {
  late final _ctrl = AnimationController(
    duration: const Duration(milliseconds: 400),
    vsync: this,
  );

  late final _scaleDown =
      Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(
    parent: _ctrl,
    curve: Curves.easeInQuad,
  ));

  late final _scaleUp =
      Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
    parent: _ctrl,
    curve: Curves.easeOutQuad,
  ));

  late final _ctrlIdle = AnimationController(
    duration: const Duration(milliseconds: 1400),
    vsync: this,
  );

  late final _scaleIdle =
      Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
    parent: _ctrlIdle,
    curve: Curves.easeInOut,
  ));

  bool _introduced = false;
  bool _show = false; // To play scaleDown or scaleUp
  bool _logo = true; // To show logo or icon
  IconData? _icon;

  @override
  void initState() {
    super.initState();

    _ctrl.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      _nextAnimationStep();
    });

    // Fire off the intro animation (scale up the logo)
    if (!_introduced) {
      setState(() {
        _show = true;
        _logo = true;
        _icon = null;
      });
      Future.delayed(const Duration(milliseconds: 500), () {
        _ctrl.forward();
      });
    }
  }

  _nextAnimationStep() {
    // As intro, scale up the logo ...
    if (!_introduced) {
      setState(() {
        _introduced = true;
      });

      // ... then if icon is set, scale down the logo ...
      if (widget.icon != null) {
        Future.delayed(const Duration(milliseconds: 800), () {
          setState(() {
            _show = false;
          });
          _ctrl.reset();
          _ctrl.forward();
        });
      } else {
        _ctrlIdle.repeat(reverse: true);
      }
      return;
    }

    // ... and then scale up the icon (if set)
    if (widget.icon != null && !_show) {
      setState(() {
        _show = true;
        _logo = false;
        _icon = widget.icon;
      });
      _ctrl.reset();
      _ctrl.forward();
      return;
    }

    // If icon is not set, scale up the logo (but only if allowed)
    if (widget.icon == null && widget.canShowLogo && !_show) {
      setState(() {
        _show = true;
        _logo = true;
        _icon = null;
      });
      _ctrl.reset();
      _ctrl.forward();
      return;
    }

    // When showing either icon or logo, do the idle animation
    if (_show) {
      _ctrlIdle.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _ctrlIdle.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(BigIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.icon != widget.icon) {
      _hide();
    } else if (widget.icon == null && !widget.canShowLogo) {
      _hide();
    }
    if (!oldWidget.canShowLogo && widget.canShowLogo) {
      _nextAnimationStep();
    }
  }

  _hide() {
    _ctrlIdle.stop();
    setState(() {
      _show = false;
    });
    _ctrl.reset();
    _ctrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: (widget.icon != null || widget.canShowLogo) ? 1 : 0,
      child: SizedBox(
        height: PlatformInfo().isSmallAndroid(context) ? 75 : 150,
        child: AnimatedBuilder(
            animation: foundation.Listenable.merge([_ctrl, _ctrlIdle]),
            builder: (context, child) {
              return Transform.scale(
                scale: (_show ? _scaleUp.value : _scaleDown.value),
                alignment: Alignment.center,
                child: _logo || _icon == null
                    ? _buildLogo(context)
                    : _buildIcon(context),
              );
            }),
      ),
    );
  }

  Widget _buildLogo(BuildContext context) {
    final logo = Core.act.isFamily ? "assets/images/family-logo.png" : "assets/images/blokada_logo.png";

    return Stack(
      children: [
        Transform.translate(
          offset: Offset(8 + _scaleIdle.value * 4, 8 + _scaleIdle.value * 4),
          child: Image.asset(
            logo,
            fit: BoxFit.contain,
            //filterQuality: FilterQuality.high,
            color: context.theme.textPrimary.withOpacity(0.2),
          ),
        ),
        Transform.translate(
          offset: Offset(_scaleIdle.value * -4, _scaleIdle.value * -4),
          child: Image.asset(
            logo,
            fit: BoxFit.contain,
            //filterQuality: FilterQuality.high,
            //color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildIcon(BuildContext context) {
    final size = PlatformInfo().isSmallAndroid(context) ? 95.0 : 190.0;
    return Stack(
      children: [
        Transform.translate(
          offset: Offset(8 + _scaleIdle.value * 4, 8 + _scaleIdle.value * 4),
          // offset: Offset(12, 8),
          child: Icon(
            _icon,
            size: size,
            color: context.theme.textPrimary.withOpacity(0.2),
            //color: Colors.white.withOpacity(0.2),
          ),
        ),
        Transform.translate(
          offset: Offset(_scaleIdle.value * -4, _scaleIdle.value * -4),
          // offset: Offset(4, 2),
          child: Icon(
            _icon,
            size: size + 2,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
