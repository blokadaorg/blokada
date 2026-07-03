import 'package:common/src/core/core.dart';
import 'package:common/src/features/settings/ui/retention_section.dart';
import 'package:common/src/features/stats/ui/stats_section.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/platform/device/device.dart';
import 'package:common/src/shared/automation/ids.dart';
import 'package:common/src/shared/layout/detail_route.dart';
import 'package:common/src/shared/layout/with_detail_pane.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:common/src/shared/ui/with_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart';

/// v6 activity journal. With retention enabled (or freemium sample data)
/// the journal is the master pane and tapped domains render alongside it
/// on expanded windows; without retention it renders the retention
/// opt-in alone. The search action belongs to the journal list, so it
/// shows in both layout modes regardless of the pane content.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => ActivityScreenState();
}

class ActivityScreenState extends State<ActivityScreen> with Logging {
  final _device = Core.get<DeviceStore>();
  late final _account = Core.get<AccountStore>();
  late final _routes = Core.get<DetailRoutes>();

  var _showStats = false;

  @override
  void initState() {
    super.initState();

    autorun((_) {
      final retention = _device.retention;
      setState(() {
        // Show only if retention is enabled
        // ... or if freemium since we show a sample data
        _showStats = retention == "24h" || _account.isFreemium;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_showStats) {
      return Semantics(
        identifier: AutomationIds.screenActivity,
        child: WithTopBar(
          title: "main tab activity".i18n,
          child: const RetentionSection(),
        ),
      );
    }

    return WithDetailPane(
      title: "main tab activity".i18n,
      screenSemanticsId: AutomationIds.screenActivity,
      master: const StatsSection(deviceTag: null, isHeader: false),
      detailPaths: const {Paths.deviceStatsDetail},
      trailing: (context, _) => _routes.statsFilterAction(context),
    );
  }
}
