import 'package:common/service/I18nService.dart';
import 'package:common/ui/stats/toplist.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:mobx/mobx.dart' as mobx;
import 'package:relative_scale/relative_scale.dart';
import 'dart:math' as math;

import '../../journal/journal.dart';
import '../../stage/channel.pg.dart';
import '../../stage/stage.dart';
import '../../stats/stats.dart';
import '../../util/di.dart';
import '../../util/mobx.dart';
import '../../util/trace.dart';
import '../minicard/header.dart';
import '../minicard/minicard.dart';
import '../theme.dart';
import '../stats/column_chart.dart';
import '../stats/radial_segment.dart';
import '../stats/totalcounter.dart';
import '../touch.dart';

class FamilyStatsScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const FamilyStatsScreen({Key? key, this.onBack}) : super(key: key);

  @override
  State<StatefulWidget> createState() => FamilyStatsScreenState();
}

class FamilyStatsScreenState extends State<FamilyStatsScreen> with TraceOrigin {
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
          Row(
            children: [
              const SizedBox(width: 8),
              Touch(
                onTap: widget.onBack,
                decorationBuilder: (value) {
                  return BoxDecoration(
                    color: theme.bgMiniCard.withOpacity(value),
                    borderRadius: BorderRadius.circular(4),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.only(
                      left: 2, right: 8, top: 8, bottom: 8),
                  child: Row(
                    children: [
                      Icon(CupertinoIcons.chevron_left,
                          color: theme.textSecondary, size: 18),
                      Text(
                        _store.selectedDevice ?? "No device selected",
                      ),
                    ],
                  ),
                ),
              ),
              (_store.selectedDeviceIsThisDevice)
                  ? Touch(
                      onTap: _displayDeviceRename,
                      decorationBuilder: (value) {
                        return BoxDecoration(
                          color: theme.bgMiniCard.withOpacity(value),
                          borderRadius: BorderRadius.circular(4),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(CupertinoIcons.pencil,
                            color: theme.textSecondary, size: 18),
                      ),
                    )
                  : Container(),
            ],
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
