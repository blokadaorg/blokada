import 'package:common/common/navigation.dart';
import 'package:common/common/widget/common_card.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/core/core.dart';
import 'package:common/platform/device/device.dart';
import 'package:common/platform/link/channel.pg.dart';
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
                      selected
                          ? "activity retention option 24h".i18n
                          : "activity retention option none".i18n,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    )),
                    CupertinoSwitch(
                      activeColor: context.theme.accent,
                      value: selected,
                      onChanged: (bool? value) {
                        setState(() {
                          selected = value!;
                          _device.setRetention(
                              value == true ? "24h" : "", Markers.userTap);
                        });
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
