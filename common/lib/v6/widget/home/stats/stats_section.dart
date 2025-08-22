import 'package:common/common/module/payment/payment.dart';
import 'package:common/common/navigation.dart';
import 'package:common/common/widget/freemium_screen.dart';
import 'package:common/common/widget/minicard/header.dart';
import 'package:common/common/widget/minicard/minicard.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/core/core.dart';
import 'package:common/family/module/stats/stats.dart';
import 'package:common/platform/account/account.dart';
import 'package:common/platform/stats/stats.dart';
import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart' as mobx;
import 'package:relative_scale/relative_scale.dart';

import 'column_chart.dart';
import 'radial_segment.dart';
import 'totalcounter.dart';

class V6StatsSection extends StatefulWidget {
  final bool autoRefresh;
  final ScrollController controller;

  const V6StatsSection({
    Key? key,
    required this.autoRefresh,
    required this.controller,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => V6StatsSectionState();
}

class V6StatsSectionState extends State<V6StatsSection> {
  final _store = Core.get<StatsStore>();
  late final _accountStore = Core.get<AccountStore>();

  var stats = UiStats.empty();

  bool get _isFreemium {
    return _accountStore.isFreemium;
  }

  @override
  void initState() {
    super.initState();
    if (widget.autoRefresh) {
      mobx.autorun((_) {
        setState(() {
          stats = _store.stats;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return content();
  }

  Widget content() {
    final theme = Theme.of(context).extension<BlokadaTheme>()!;
    return Stack(
      children: [
        IgnorePointer(
          ignoring: _isFreemium,
          child: Container(
            decoration: BoxDecoration(
              color: theme.bgColor,
            ),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: maxContentWidth),
                child: RelativeBuilder(builder: (context, height, width, sy, sx) {
                  return Column(
                    children: [
                      const SizedBox(height: 42),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: MiniCard(
                          child: Column(
                            children: [
                              MiniCardHeader(
                                text: "stats header day".i18n,
                                icon: Icons.timelapse,
                                color: theme.textSecondary,
                              ),
                              const SizedBox(height: 4),
                              RadialSegment(autoRefresh: widget.autoRefresh),
                              const SizedBox(height: 16),
                              const Divider(),
                              ColumnChart(stats: stats),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: TotalCounter(autoRefresh: widget.autoRefresh),
                      ),
                      const Spacer(),
                      SizedBox(height: sy(60)),
                    ],
                  );
                }),
              ),
            ),
          ),
        ),
        (_isFreemium)
            ? FreemiumScreen(
                title: "freemium activity cta header".i18n,
                subtitle: "freemium activity cta desc".i18n,
                placement: Placement.freemiumStats,
              )
            : Container(),
      ],
    );
  }
}
