import 'dart:ui';

import 'package:common/common/module/payment/payment.dart';
import 'package:common/core/core.dart';
import 'package:flutter/material.dart';

// Blurs the child widget with a backdrop filter effect.
// Used for freemium mode when some Texts and other widgets are blurred.
// For non freemium mode, it will just show the child.
class FreemiumBlur extends StatelessWidget {
  final double blurX;
  final double blurY;
  final Widget child;

  FreemiumBlur({
    super.key,
    this.blurX = 5,
    this.blurY = 2,
    required this.child,
  });

  late final _payment = Core.get<PaymentActor>();

  @override
  Widget build(BuildContext context) {
    if (!Core.act.isFreemium) {
      return child;
    }

    return GestureDetector(
      onTap: () => _payment.openPaymentScreen(Markers.userTap),
      child: Stack(
        children: [
          child,
          // Blur overlay (with same border radius if provided)
          Positioned.fill(
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blurX, sigmaY: blurY),
                child: Container(
                  color: Colors.transparent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
