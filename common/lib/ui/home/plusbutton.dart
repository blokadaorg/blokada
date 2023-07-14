import 'package:common/service/I18nService.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart' as mobx;

import '../../account/account.dart';
import '../../app/app.dart';
import '../../app/channel.pg.dart';
import '../../perm/perm.dart';
import '../../plus/gateway/gateway.dart';
import '../../plus/plus.dart';
import '../../stage/channel.pg.dart';
import '../../stage/stage.dart';
import '../../util/di.dart';
import '../../util/trace.dart';
import '../minicard/minicard.dart';
import '../theme.dart';

class PlusButton extends StatefulWidget {
  PlusButton({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _PlusButtonState();
  }
}

class _PlusButtonState extends State<PlusButton>
    with TickerProviderStateMixin, TraceOrigin {
  final _app = dep<AppStore>();
  final _account = dep<AccountStore>();
  final _gateway = dep<PlusGatewayStore>();
  final _stage = dep<StageStore>();
  final _plus = dep<PlusStore>();
  final _perm = dep<PermStore>();

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
                    color: theme.plus,
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
                    color: theme.plus,
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
              activeColor: theme.plus,
              onChanged: (value) {
                setState(() {
                  if (location.isEmpty) {
                    _displayLocations();
                  } else {
                    activated = value;
                    traceAs("tappedSwitchPlus", (trace) async {
                      await _plus.switchPlus(trace, value);
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
    traceAs("tappedDisplayLocations", (trace) async {
      if (_perm.vpnEnabled) {
        await _stage.showModal(trace, StageModal.plusLocationSelect);
      } else {
        await _stage.showModal(trace, StageModal.onboarding);
      }
    });
  }

  _displayPayments() {
    traceAs("tappedDisplayPayments", (trace) async {
      await _stage.showModal(trace, StageModal.payment);
    });
  }
}
