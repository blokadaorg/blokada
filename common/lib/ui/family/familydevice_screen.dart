import 'package:common/service/I18nService.dart';
import 'package:common/ui/stats/toplist.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:relative_scale/relative_scale.dart';

import '../../common/model.dart';
import '../../common/widget.dart';
import '../../journal/journal.dart';
import '../../stage/channel.pg.dart';
import '../../stage/stage.dart';
import '../../stats/stats.dart';
import '../../util/di.dart';
import '../../util/mobx.dart';
import '../../util/trace.dart';
import '../theme.dart';
import '../stats/column_chart.dart';
import '../stats/radial_segment.dart';

class FamilyDeviceScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const FamilyDeviceScreen({Key? key, this.onBack}) : super(key: key);

  @override
  State<StatefulWidget> createState() => FamilyDeviceScreenState();
}

class FamilyDeviceScreenState extends State<FamilyDeviceScreen>
    with TraceOrigin {
  final _store = dep<StatsStore>();
  final _stage = dep<StageStore>();
  final _journal = dep<JournalStore>();

  late UiStats _stats;

  @override
  void initState() {
    super.initState();

    setState(() {
      _stats = _store.statsForSelectedDevice();
    });

    reactionOnStore((_) => _store.deviceStatsChangesCounter, (_) async {
      if (!mounted) return;
      setState(() {
        _stats = _store.statsForSelectedDevice();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return content();
  }

  Widget content() {
    final theme = Theme.of(context).extension<BlokadaTheme>()!;
    return RelativeBuilder(builder: (context, height, width, sy, sx) {
      return ListView(
        children: [
          const SizedBox(height: 8),
          BackEditHeaderWidget(
            name: _store.selectedDevice ?? "No selected device",
            onBack: widget.onBack,
            onEdit: _displayDeviceRename,
          ),
          SizedBox(
            width: width > 600 ? 600 : width,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: MiniCard(
                child: Column(
                  children: [
                    MiniCardHeader(
                      text: "stats header day".i18n,
                      icon: CupertinoIcons.clock,
                      color: theme.textSecondary,
                    ),
                    const SizedBox(height: 4),
                    const RadialSegment(autoRefresh: true),
                    const SizedBox(height: 16),
                    const Divider(),
                    ColumnChart(stats: _stats),
                  ],
                ),
              ),
            ),
          ),
          Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: MiniCard(
                child: Column(
                  children: [
                    MiniCardHeader(
                      text: "activity category top blocked".i18n,
                      icon: CupertinoIcons.chart_bar,
                      color: theme.textSecondary,
                    ),
                    Toplist(stats: _stats, blocked: true),
                  ],
                ),
              ),
            ),
          ),
          Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: MiniCard(
                child: Column(
                  children: [
                    MiniCardHeader(
                      text: "activity category top allowed".i18n,
                      icon: CupertinoIcons.chart_bar,
                      color: theme.textSecondary,
                    ),
                    Toplist(stats: _stats, blocked: false),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: sy(60)),
        ],
      );
    });
  }

  _displayDeviceRename() {
    traceAs("tappedDeviceRename", (trace) async {
      await _stage.showModal(trace, StageModal.deviceAlias);
    });
  }

  _openActivityForSelectedDevice() {
    traceAs("tappedActivity", (trace) async {
      await _stage.setRoute(trace, StageTab.activity.name);
      await _journal.updateFilter(trace,
          deviceName: _store.selectedDevice, searchQuery: "");
    });
  }
}
