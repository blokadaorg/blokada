import 'package:common/common/widget/minicard/minicard.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/core/core.dart';
import 'package:common/platform/account/account.dart';
import 'package:common/platform/app/app.dart';
import 'package:common/platform/app/channel.pg.dart';
import 'package:common/platform/perm/perm.dart';
import 'package:common/platform/plus/gateway/gateway.dart';
import 'package:common/platform/plus/plus.dart';
import 'package:common/platform/stage/channel.pg.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart' as mobx;

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
  final _gateway = Core.get<PlusGatewayStore>();
  final _stage = Core.get<StageStore>();
  final _plus = Core.get<PlusStore>();
  final _permVpnEnabled = Core.get<VpnEnabled>();

  var activated = false;
  var location = "";
  var isPlus = false;

  @override
  void initState() {
    super.initState();

    mobx.autorun((_) {
      final status = _app.status;
      final gateway = _gateway.currentGateway;
      final plusEnabled =
          _plus.plusEnabled && status == AppStatus.activatedPlus;

      setState(() {
        location = gateway?.niceName ?? "";
        activated = plusEnabled;
        isPlus = _account.type == AccountType.plus;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<BlokadaTheme>()!;
    return SizedBox(
        height: 48,
        child: Stack(
          children: [
            // When switch is off
            AnimatedOpacity(
                opacity: (!isPlus || activated) ? 0 : 1,
                duration: const Duration(milliseconds: 500),
                child: MiniCard(
                    color: theme.accent,
                    onTap: () {
                      _displayLocations();
                    },
                    child: _buildButtonContent())),
            // When switch is on
            IgnorePointer(
              ignoring: !activated,
              child: AnimatedOpacity(
                  opacity: activated ? 1 : 0,
                  duration: const Duration(milliseconds: 500),
                  child: MiniCard(
                      outlined: true,
                      onTap: () {
                        _displayLocations();
                      },
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
                              child: Text("universal action upgrade".i18n)))
                    ]),
                  )),
            )
          ],
        ));
  }

  Widget _buildButtonContent() {
    final theme = Theme.of(context).extension<BlokadaTheme>()!;

    return Row(
      children: [
        activated
            ? (Text("home plus button location"
                .i18n
                .fill([location]).replaceAll("*", "")))
            : (Text("home plus button select location".i18n)),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: CupertinoSwitch(
              value: activated,
              activeColor: theme.accent,
              onChanged: (value) {
                setState(() {
                  if (location.isEmpty) {
                    _displayLocations();
                  } else {
                    activated = value;
                    log(Markers.userTap).trace("tappedSwitchPlus", (m) async {
                      await _plus.switchPlus(value, m);
                    });
                  }
                });
              },
            ),
          ),
        )
      ],
    );
  }

  _displayLocations() {
    log(Markers.userTap).trace("tappedDisplayLocations", (m) async {
      if (_permVpnEnabled.present == true) {
        await _stage.showModal(StageModal.plusLocationSelect, m);
      } else {
        await _stage.showModal(StageModal.perms, m);
      }
    });
  }

  _displayPayments() {
    log(Markers.userTap).trace("tappedDisplayPayments", (m) async {
      await _stage.showModal(StageModal.payment, m);
    });
  }
}
