import 'package:common/common/module/payment/payment.dart';
import 'package:common/common/widget/minicard/header.dart';
import 'package:common/common/widget/minicard/minicard.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/core/core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class FreemiumCounter extends StatefulWidget {
  const FreemiumCounter({Key? key}) : super(key: key);

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
      _payment.openPaymentScreen(Markers.userTap); // TODO: placementID
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<BlokadaTheme>()!;
    return Column(
      children: [
        MiniCard(
          onTap: _onTap,
          outlined: true,
          child: Column(
            children: [
              MiniCardHeader(
                text: "Freemium",
                icon: Icons.shield_outlined,
                color: theme.freemium,
              ),
              SizedBox(height: 12),
              Text(
                  "You are using Blokada in freemium mode. Adblocking is active in your Safari (also YouTube ads)."),
            ],
          ),
        ),
        SizedBox(height: 16),
        _buildCta(context),
      ],
    );
  }

  Widget _buildCta(BuildContext context) {
    return MiniCard(
        onTap: _onTap,
        color: context.theme.accent,
        child: SizedBox(
          height: 28,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                CupertinoIcons.heart_fill,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Center(
                child: Text(
                  "universal action upgrade short".i18n,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ));
  }
}
