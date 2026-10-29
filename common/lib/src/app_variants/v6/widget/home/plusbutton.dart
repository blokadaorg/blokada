import 'package:common/src/shared/ui/blokada_switch.dart';
import 'package:common/src/features/payment/domain/payment.dart';
import 'package:common/src/shared/ui/minicard/minicard.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/app_variants/family/module/perm/perm.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/platform/app/app.dart';
import 'package:common/src/platform/app/channel.pg.dart';
import 'package:common/src/platform/perm/perm.dart';
import 'package:common/src/platform/stage/channel.pg.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'package:common/src/features/plus/domain/gateway/gateway.dart';
import 'package:common/src/features/plus/domain/plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart' as mobx;
import 'dart:async';
import 'package:common/src/shared/ui/haptics.dart';

class PlusButton extends StatefulWidget {
  PlusButton({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _PlusButtonState();
  }
}

class _PlusButtonState extends State<PlusButton>
    with TickerProviderStateMixin, Logging {
  final _app = Core.get<AppStore>();
  final _account = Core.get<AccountStore>();
  final _gateway = Core.get<CurrentGatewayValue>();
  final _stage = Core.get<StageStore>();
  final _plus = Core.get<PlusActor>();
  final _plusEnabled = Core.get<PlusEnabledValue>();
  final _permVpnEnabled = Core.get<VpnEnabledValue>();
  final _permChannel = Core.get<PermChannel>();
  final _payment = Core.get<PaymentActor>();

  var activated = false;
  var location = "";
  var isPlus = false;

  // The user switched Plus on and it is not up yet: the success run plays
  // once it is, which can be minutes later when the OS holds the start.
  var _successPending = false;

  @override
  void initState() {
    super.initState();

    mobx.autorun((_) {
      final status = _app.status;
      final gateway = _gateway.present;
      final plusEnabled =
          _plusEnabled.present == true && status == AppStatus.activatedPlus;

      if (_successPending && plusEnabled) {
        _successPending = false;
        unawaited(Haptics.success());
      } else if (_plusEnabled.present != true) {
        _successPending = false;
      }

      setState(() {
        final flag = gateway?.flag;
        location = gateway == null
            ? ""
            : (flag == null ? gateway.niceName : "$flag ${gateway.niceName}");
        activated = plusEnabled;
        isPlus = _account.type == AccountType.plus;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<BlokadaTheme>()!;
    // 48 tall, which slightly squeezes a line of default-size text. Above the
    // default text size the cards grow instead (each layer at least 48, via
    // passthrough), so a wrapped location fits.
    final grow = MediaQuery.textScalerOf(context).scale(1) > 1;
    return ConstrainedBox(
        constraints: grow
            ? const BoxConstraints(minHeight: 48)
            : const BoxConstraints.tightFor(height: 48),
        child: Stack(
          fit: grow ? StackFit.passthrough : StackFit.loose,
          alignment: Alignment.center,
          children: [
            // When switch is off
            AnimatedOpacity(
                opacity: (!isPlus || activated) ? 0 : 1,
                duration: const Duration(milliseconds: 500),
                child: MiniCard(
                    color: theme.accent,
                    onTap: () => _doActionOrAskPerm(_displayLocations),
                    child: _buildButtonContent(textColor: theme.onAccent))),
            // When switch is on
            IgnorePointer(
              ignoring: !activated,
              child: AnimatedOpacity(
                  opacity: activated ? 1 : 0,
                  duration: const Duration(milliseconds: 500),
                  child: MiniCard(
                      outlined: true,
                      onTap: () => _doActionOrAskPerm(_displayLocations),
                      child: _buildButtonContent())),
            ),
            // When account is not Plus (CTA)
            IgnorePointer(
              ignoring: isPlus,
              child: AnimatedOpacity(
                  opacity: isPlus ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: MiniCard(
                    color: theme.accent,
                    onTap: () {
                      _displayPayments();
                    },
                    child: Flex(direction: Axis.horizontal, children: [
                      Expanded(
                          child: Align(
                              child: Text("universal action upgrade".i18n,
                                  style: TextStyle(color: theme.onAccent))))
                    ]),
                  )),
            )
          ],
        ));
  }

  Widget _buildButtonContent({Color? textColor}) {
    final theme = Theme.of(context).extension<BlokadaTheme>()!;

    final row = Row(
      children: [
        // Wraps with large text, keeping the switch on the right.
        Expanded(
          child: activated
              ? (Text("home plus button location"
                  .i18n
                  .fill([location]).replaceAll("*", "")))
              : (Text("home plus button select location".i18n)),
        ),
        // The height the switch always had in the 48 tall card.
        SizedBox(
            height: 24,
            child: BlokadaSwitch(
              value: activated,
              activeColor: theme.accent,
              // Plus on rises and off falls, like the power button.
              haptic: false,
              onChanged: (value) {
                unawaited(value ? Haptics.switchOn() : Haptics.switchOff());
                setState(() {
                  _doActionOrAskPerm((m) async {
                    activated = value;
                    // Plus coming up plays the same rising run as protection.
                    _successPending = value;
                    try {
                      await _plus.switchPlus(value, m);
                    } catch (_) {
                      _successPending = false;
                      rethrow;
                    }
                  });
                });
              },
            ),
        )
      ],
    );
    if (textColor == null) return row;
    return DefaultTextStyle.merge(style: TextStyle(color: textColor), child: row);
  }

  _doActionOrAskPerm(Future<void> Function(Marker m) action) {
    log(Markers.userTap).trace("tappedPlusButton", (m) async {
      if (_permVpnEnabled.present == true) {
        await action(m);
      } else {
        await _permChannel.doAskVpnPerms();
      }
    });
  }

  Future<void> _displayLocations(Marker m) async {
    unawaited(Haptics.tap());
    await _stage.showModal(StageModal.plusLocationSelect, m);
  }

  _displayPayments() {
    log(Markers.userTap).trace("tappedDisplayPayments", (m) async {
      await _payment.openPaymentScreen(m, placement: Placement.plusUpgrade);
    });
  }
}
