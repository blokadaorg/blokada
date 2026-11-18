import 'package:common/src/features/payment/domain/payment.dart';
import 'package:common/src/shared/ui/minicard/header.dart';
import 'package:common/src/shared/ui/minicard/minicard.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/core/core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class FreemiumCounter extends StatefulWidget {
  /// The upgrade button above the status card, for Home's compact
  /// arrangement, where the card's text can fill the screen at large sizes.
  final bool ctaFirst;

  const FreemiumCounter({Key? key, this.ctaFirst = false}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _FreemiumCounterState();
  }
}

class _FreemiumCounterState extends State<FreemiumCounter> with TickerProviderStateMixin, Logging {
  final _payment = Core.get<PaymentActor>();

  @override
  void initState() {
    super.initState();
  }

  _onTap() {
    log(Markers.userTap).trace("tappedUpgradeFreemiumHome", (m) async {
      _payment.openPaymentScreen(Markers.userTap, placement: Placement.freemiumHome);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<BlokadaTheme>()!;
    final status = MiniCard(
      onTap: _onTap,
      outlined: true,
      child: Column(
        children: [
          MiniCardHeader(
            text: "freemium home status header".i18n,
            icon: Icons.shield_outlined,
            color: theme.freemium,
          ),
          const SizedBox(height: 12),
          Text("freemium home status desc safari".i18n),
        ],
      ),
    );
    final cta = _buildCta(context);
    return Column(
      children: widget.ctaFirst
          ? [cta, const SizedBox(height: 16), status]
          : [status, const SizedBox(height: 16), cta],
    );
  }

  Widget _buildCta(BuildContext context) {
    return MiniCard(
      onTap: _onTap,
      color: context.theme.accent,
      // 28 tall at the default size; grows with large text, wrapping
      // rather than cutting the label.
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 28),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.heart_fill, color: context.theme.onAccent),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                "universal action upgrade short".i18n,
                textAlign: TextAlign.center,
                style: context.theme.text.body.semibold.copyWith(color: context.theme.onAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
