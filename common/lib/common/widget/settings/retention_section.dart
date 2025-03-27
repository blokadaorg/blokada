import 'package:common/common/module/link/link.dart';
import 'package:common/common/navigation.dart';
import 'package:common/common/widget/common_card.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/core/core.dart';
import 'package:common/platform/device/device.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:common/util/mobx.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class RetentionSection extends StatefulWidget {
  final bool primary;

  const RetentionSection({Key? key, this.primary = true}) : super(key: key);

  @override
  State<StatefulWidget> createState() => RetentionSectionState();
}

class RetentionSectionState extends State<RetentionSection> with Logging {
  late final _device = Core.get<DeviceStore>();
  late final _stage = Core.get<StageStore>();

  bool selected = false;

  @override
  void initState() {
    super.initState();
    reactionOnStore((_) => _device.retention, (retention) {
      _reload();
    });
    _reload();
  }

  _reload() {
    setState(() {
      selected = _device.retention == "24h";
    });
  }

  _setRetention(BuildContext context, bool enabled) async {
    await _device.setRetention(enabled ? "24h" : "", Markers.userTap);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: ListView(
          primary: widget.primary,
          children: [
            SizedBox(height: getTopPadding(context)),
            CommonCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
                child: Text("activity retention desc".i18n,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge!
                        .copyWith(color: context.theme.textSecondary))),
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 24.0, bottom: 12),
              child: Text("activity actions header".i18n,
                  style: Theme.of(context).textTheme.headlineMedium),
            ),
            CommonCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                        child: Text(
                      "activity retention option 24h".i18n,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    )),
                    CupertinoSwitch(
                      activeColor: context.theme.accent,
                      value: selected,
                      onChanged: (bool? value) async {
                        setState(() {
                          selected = value!;
                        });

                        // No async to not lag, but lags anyway
                        _setRetention(context, value!);
                      },
                    ),
                  ],
                )),
            GestureDetector(
              onTap: () {
                _stage.openLink(LinkId.privacyCloud, Markers.userTap);
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
                child: Text("activity retention policy".i18n,
                    style: TextStyle(color: context.theme.accent)),
              ),
            ),
          ],
        ));
  }
}
