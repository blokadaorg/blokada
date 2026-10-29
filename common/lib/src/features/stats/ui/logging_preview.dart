import 'dart:async';

import 'package:common/src/core/core.dart';
import 'package:common/src/features/link/domain/link.dart';
import 'package:common/src/features/stats/domain/controller.dart';
import 'package:common/src/features/stats/domain/sample.dart';
import 'package:common/src/features/stats/ui/activity_item.dart';
import 'package:common/src/features/toast/domain/toast.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'package:common/src/shared/automation/ids.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:common/src/shared/ui/common_divider.dart';
import 'package:common/src/shared/ui/freemium_screen.dart';
import 'package:common/src/shared/ui/haptics.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/cupertino.dart';

/// The offer over the sample Privacy Pulse and Activity while activity
/// logging is off (the default): what turning it on keeps and for how long,
/// and one tap to turn it on. Settings keeps the switch to turn it off.
class LoggingOffer extends StatelessWidget {
  const LoggingOffer({super.key});

  Future<void> _enable() async {
    unawaited(Haptics.switchOn());
    try {
      await Core.get<StatsController>().enableLogging(Markers.userTap);
    } catch (_) {
      // Logged by enableLogging.
      Core.get<ToastActor>().showError("toast save failed".i18n);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FreemiumScreen(
      badge: "activity logging sample".i18n,
      title: "activity logging offer header".i18n,
      subtitle: "activity logging offer brief".i18n,
      actionLabel: "activity logging action enable".i18n,
      actionIcon: CupertinoIcons.chart_bar_alt_fill,
      actionSemanticsId: AutomationIds.loggingEnable,
      onAction: _enable,
      footer: GestureDetector(
        onTap: () => Core.get<StageStore>().openLink(LinkId.privacyCloud, Markers.userTap),
        child: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            "activity retention policy".i18n,
            textAlign: TextAlign.center,
            style: context.theme.linkStyle(context.theme.text.callout),
          ),
        ),
      ),
    );
  }
}

/// Sample rows for the Activity list behind [LoggingOffer], laid out like
/// the real list.
class SampleActivityList extends StatelessWidget {
  const SampleActivityList({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = LoggingSample.journal();
    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: ListView(
          primary: false,
          children: [
            SizedBox(height: getTopPadding(context)),
            Container(
              decoration: BoxDecoration(
                color: context.theme.bgMiniCard,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  for (var i = 0; i < entries.length; i++) ...[
                    ActivityItem(entry: entries[i]),
                    if (i < entries.length - 1) const CommonDivider(indent: 60),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
