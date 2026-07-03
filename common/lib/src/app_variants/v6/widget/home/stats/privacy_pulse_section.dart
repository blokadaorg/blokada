import 'dart:async';

import 'package:common/src/features/journal/domain/journal.dart';
import 'package:common/src/shared/automation/ids.dart';
import 'package:common/src/shared/navigation.dart' show maxContentWidth, getTopPadding;
import 'package:common/src/features/notification/domain/notification.dart';
import 'package:common/src/shared/ui/minicard/minicard.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/features/weekly/ui/weekly_report_card.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/app_variants/family/module/stats/stats.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/platform/device/device.dart';
import 'package:common/src/platform/stats/stats.dart';
import 'package:common/src/platform/stats/delta_store.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:mobx/mobx.dart' as mobx;
import 'package:timeago/timeago.dart' as timeago;

import 'package:common/src/features/stats/ui/privacy_pulse_charts.dart';
import 'package:common/src/features/stats/ui/recent_activity.dart';
import 'package:common/src/features/stats/ui/top_domains.dart';
import 'package:common/src/features/stats/ui/totalcounter.dart';

class PrivacyPulseSection extends StatefulWidget {
  final bool autoRefresh;
  final ScrollController controller;
  final ToplistRange? initialRange;

  const PrivacyPulseSection({
    Key? key,
    required this.autoRefresh,
    required this.controller,
    this.initialRange,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => PrivacyPulseSectionState();
}

class PrivacyPulseSectionState extends State<PrivacyPulseSection> with Logging {
  final _store = Core.get<StatsStore>();
  late final _accountStore = Core.get<AccountStore>();
  late final _deviceStore = Core.get<DeviceStore>();
  late final _journal = Core.get<JournalActor>();
  late final _weeklyReport = Core.get<WeeklyReportActor>();
  late final _deltaStore = Core.get<StatsDeltaStore>();

  var stats = UiStats.empty();
  bool _toplistsFetched = false;
  WeeklyReportEvent? _weeklyEvent;
  WeeklyReportToplistHighlight? _weeklyHighlight;
  final List<mobx.ReactionDisposer> _disposers = [];
  final _topDomainsHeaderKey = GlobalKey();
  ToplistRange _toplistRange = ToplistRange.daily;
  Future<void>? _pendingStatsRequest;
  Future<void>? _pendingToplistRequest;
  StatsCounters _counters = StatsCounters.empty();
  final Map<ToplistRange, List<ToplistDelta>> _blockedDeltas = {};
  final Map<ToplistRange, List<ToplistDelta>> _allowedDeltas = {};
  final Map<ToplistRange, CounterDelta> _counterDeltas = {};
  DailySeries? _weeklySparkline;
  bool _hasStats = false;
  final Map<ToplistRange, bool> _deltaReady = {
    ToplistRange.daily: false,
    ToplistRange.weekly: false,
  };

  bool get _isFreemium {
    return _accountStore.isFreemium;
  }

  @override
  void initState() {
    super.initState();
    _toplistRange = widget.initialRange ?? ToplistRange.daily;
    if (widget.autoRefresh) {
      mobx.autorun((_) {
        setState(() {
          stats = _store.stats;
          _hasStats = _store.hasStats;
        });
      });
    }

    // Watch for deviceAlias to become available and fetch toplists
    _disposers.add(mobx.autorun((_) {
      final deviceAlias = _deviceStore.deviceAlias;
      if (deviceAlias.isNotEmpty) {
        _kickoffStatsFetch();

        unawaited(_refreshDeltas());
        unawaited(_updateCounters());
        unawaited(_updateWeeklySparkline());

        if (!_toplistsFetched) {
          _toplistsFetched = true;
          unawaited(_fetchToplists());
        }
      }
    }));

    _disposers.add(mobx.autorun((_) {
      setState(() {
        _weeklyEvent = _weeklyReport.currentEvent.value;
        final highlight = _weeklyEvent?.toplistHighlight;
        if (highlight != null) {
          _weeklyHighlight = highlight;
        }
      });
    }));
  }

  @override
  void dispose() {
    for (final disposer in _disposers) {
      disposer();
    }
    super.dispose();
  }

  Future<void> _kickoffStatsFetch({bool force = false}) {
    if (!force && _pendingStatsRequest != null) {
      return _pendingStatsRequest!;
    }

    final future = _store.fetchDay(Markers.stats, force: force).then((_) async {
      await _store.fetchWeek(Markers.stats, force: force);
    });
    _pendingStatsRequest = future;
    return future.whenComplete(() {
      if (_pendingStatsRequest == future) {
        _pendingStatsRequest = null;
      }
    });
  }

  Future<void> _fetchToplists({ToplistRange? rangeOverride}) {
    final selectedRange = rangeOverride ?? _toplistRange;
    final future = log(Markers.userTap).trace("privacyPulseFetchToplists", (m) async {
      await _store.fetchToplists(
        m,
        range: selectedRange == ToplistRange.daily ? "24h" : "7d",
      );
    });
    _pendingToplistRequest = future;
    return future.whenComplete(() {
      if (_pendingToplistRequest == future) {
        _pendingToplistRequest = null;
      }
    });
  }

  Future<void> _refreshDeltas({ToplistRange? rangeOverride}) async {
    final range = rangeOverride ?? _toplistRange;
    setState(() {
      _deltaReady[range] = false;
    });
    final deviceName = _deviceStore.deviceAlias;
    if (deviceName.isEmpty) return;
    final label = range == ToplistRange.daily ? "24h" : "7d";
    await _deltaStore.refresh(Markers.stats, deviceName: deviceName, range: label, force: false);
    if (!mounted) return;
    setState(() {
      _blockedDeltas[range] = _deltaStore.deltasFor(deviceName, label, blocked: true);
      _allowedDeltas[range] = _deltaStore.deltasFor(deviceName, label, blocked: false);
      _counterDeltas[range] = _deltaStore.counterDeltaFor(deviceName, label);
      _deltaReady[range] = true;
    });
  }

  Future<void> _updateCounters({bool force = false}) async {
    final rangeLabel = _toplistRange == ToplistRange.daily ? "24h" : "7d";
    final counters = await _store.countersForRange(rangeLabel, Markers.stats, force: force);
    if (!mounted) return;
    setState(() {
      _counters = counters;
    });
  }

  Future<void> _updateWeeklySparkline({bool force = false}) async {
    if (_toplistRange != ToplistRange.weekly) return;
    final series = await _store.allowedDailySeries(Markers.stats, days: 7, force: force);
    if (!mounted) return;
    setState(() {
      _weeklySparkline = series;
    });
  }

  Future<void> _pullToRefresh() async {
    return await log(Markers.userTap).trace("privacyPulsePullToRefresh", (m) async {
      await _kickoffStatsFetch(force: true);
      await _updateCounters(force: true);
      await _updateWeeklySparkline(force: true);
      await _refreshDeltas(rangeOverride: _toplistRange);
      await _journal.fetch(m, tag: null);
      await _store.fetchToplists(
        m,
        range: _toplistRange == ToplistRange.daily ? "24h" : "7d",
      );
    });
  }

  Future<void> _setToplistRange(ToplistRange range) async {
    if (_toplistRange != range) {
      mobx.runInAction(() {
        _store.toplistsLoading = true;
      });
      setState(() {
        _toplistRange = range;
      });
      await _updateCounters(force: true);
      await _updateWeeklySparkline(force: true);
      await _refreshDeltas(rangeOverride: range);
      await _fetchToplists(rangeOverride: range);
      return;
    }

    final pending = _pendingToplistRequest;
    if (pending != null) {
      await pending;
    }
  }

  @override
  Widget build(BuildContext context) {
    return content();
  }

  /// Above this width the pulse sections spread over two columns. Low
  /// enough that both columns survive (shrunk to phone-ish width) next to
  /// an open detail pane on landscape iPads. The screen also uses this as
  /// its minSplitMasterWidth so the master never collapses to a single
  /// column mid-split — where it can't keep two columns, details push
  /// full-screen instead.
  static const double twoColumnMinWidth = 780.0;

  /// Two 500pt columns + the 24pt gutter + the 12pt outer paddings.
  static const double _twoColumnMaxWidth = 1048.0;

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
            child: LayoutBuilder(builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= twoColumnMinWidth;
              return Center(
                child: Container(
                  constraints: BoxConstraints(
                      maxWidth: twoColumns ? _twoColumnMaxWidth : maxContentWidth),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: PrimaryScrollController(
                      controller: widget.controller,
                      child: RefreshIndicator(
                        displacement: 100.0,
                        onRefresh: _pullToRefresh,
                        child: ListView(
                          controller: widget.controller,
                          children: [
                            SizedBox(height: getTopPadding(context)),
                            // Cross-fade the column-mode change so the
                            // relayout during the master/detail width
                            // animation doesn't read as tearing.
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: KeyedSubtree(
                                key: ValueKey(twoColumns),
                                child: twoColumns
                                    ? _buildTwoColumnContent(context)
                                    : Column(children: _buildSingleColumnContent(context)),
                              ),
                            ),
                            const SizedBox(height: 60),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildSingleColumnContent(BuildContext context) {
    return [
      ..._buildWeeklyCard(context),
      _buildChartsCard(context),
      const SizedBox(height: 12),
      _buildTopDomains(),
      const SizedBox(height: 12),
      RecentActivity(),
      const SizedBox(height: 48),
      TotalCounter(stats: stats),
    ];
  }

  /// Wide layout: the chart pairs with the short recent-activity preview on
  /// the left, while the tall top-domains list sits under the all-time
  /// counter on the right, so the columns carry comparable weight and share
  /// one scroll position.
  Widget _buildTwoColumnContent(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              ..._buildWeeklyCard(context),
              _buildChartsCard(context),
              const SizedBox(height: 12),
              RecentActivity(),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            children: [
              TotalCounter(stats: stats),
              const SizedBox(height: 24),
              _buildTopDomains(),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildWeeklyCard(BuildContext context) {
    if (_weeklyEvent == null) return const [];
    return [
      Builder(builder: (context) {
        final event = _weeklyEvent!;
        final isToplist = event.type == WeeklyReportEventType.toplistChange;
        final timeLabel = timeago.format(event.generatedAt, allowFromNow: true);
        return WeeklyReportCard(
          title: event.title,
          content: Text(
            event.body,
            style: TextStyle(
              fontSize: 14,
              color: context.theme.textSecondary,
              height: 1.3,
            ),
          ),
          time: timeLabel,
          icon: _iconFor(event.icon),
          iconColor: context.theme.accent,
          onTap: isToplist ? _handleWeeklyReportTap : null,
          onDismiss: () => _dismissWeeklyReport(),
        );
      }),
      const SizedBox(height: 16),
    ];
  }

  Widget _buildChartsCard(BuildContext context) {
    return MiniCard(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: PrivacyPulseCharts(
          stats: stats,
          counters: _counters,
          counterDelta: _counterDeltas[_toplistRange],
          statsReady: _hasStats,
          deltaReady: _deltaReady[_toplistRange] ?? false,
          sparklineSeries: _toplistRange == ToplistRange.weekly ? _weeklySparkline : null,
          trailing: _buildToplistRangeToggle(context),
        ),
      ),
    );
  }

  Widget _buildTopDomains() {
    return TopDomains(
      headerKey: _topDomainsHeaderKey,
      highlight: _weeklyHighlight ?? _weeklyEvent?.toplistHighlight,
      range: _toplistRange,
      blockedDeltas: _blockedDeltas[_toplistRange],
      allowedDeltas: _allowedDeltas[_toplistRange],
      onRangeChanged: _setToplistRange,
    );
  }

  void _handleWeeklyReportTap() {
    if (_weeklyEvent?.type != WeeklyReportEventType.toplistChange) return;
    // Remove the card first to avoid layout jank, then scroll once the frame is updated.
    _dismissWeeklyReport(keepHighlight: true);
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      await _scrollAndEnsureWeeklyHighlight();
    });
  }

  Widget _buildToplistRangeToggle(BuildContext context) {
    return CupertinoSlidingSegmentedControl<ToplistRange>(
      groupValue: _toplistRange,
      onValueChanged: (ToplistRange? value) {
        if (value != null) {
          unawaited(_setToplistRange(value));
        }
      },
      children: {
        ToplistRange.daily: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: MergeSemantics(
            child: Semantics(
              identifier: AutomationIds.privacyPulseRangeDaily,
              selected: _toplistRange == ToplistRange.daily,
              child: Text(
                "24 h",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.theme.textPrimary,
                ),
              ),
            ),
          ),
        ),
        ToplistRange.weekly: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: MergeSemantics(
            child: Semantics(
              identifier: AutomationIds.privacyPulseRangeWeekly,
              selected: _toplistRange == ToplistRange.weekly,
              child: Text(
                "7 d",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.theme.textPrimary,
                ),
              ),
            ),
          ),
        ),
      },
    );
  }

  Future<void> _scrollAndEnsureWeeklyHighlight() async {
    await _scrollToTopDomains(force: true);
    if (_toplistRange != ToplistRange.weekly) {
      await _setToplistRange(ToplistRange.weekly);
    }
  }

  Future<void> _scrollToTopDomains({int attempt = 0, bool force = false}) async {
    if (!force && _toplistRange != ToplistRange.weekly) {
      log(Markers.userTap).t('weeklyReport:scroll:wrongRange');
      return;
    }

    final keyContext = _topDomainsHeaderKey.currentContext;
    final logger = log(Markers.userTap)..t('weeklyReport:scroll:trigger');
    const double topOffset = 120.0;

    if (!widget.controller.hasClients) {
      logger.t('weeklyReport:scroll:noClients');
      return;
    }

    if (keyContext == null) {
      logger
        ..t('weeklyReport:scroll:noContext')
        ..pair('attempt', attempt);
      if (attempt >= 2) return;
      final mid = widget.controller.position.maxScrollExtent * 0.5;
      try {
        await widget.controller.animateTo(
          mid,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } catch (_) {
        return;
      }
      await SchedulerBinding.instance.endOfFrame;
      await _scrollToTopDomains(attempt: attempt + 1, force: force);
      return;
    }

    try {
      logger
        ..t('weeklyReport:scroll:ensureVisible')
        ..pair('currentOffset', widget.controller.offset);

      final renderObject = keyContext.findRenderObject();
      final viewport = RenderAbstractViewport.of(renderObject);
      if (renderObject != null && viewport != null) {
        final target = viewport.getOffsetToReveal(renderObject, 0).offset - topOffset;
        final clamped = target.clamp(
          widget.controller.position.minScrollExtent,
          widget.controller.position.maxScrollExtent,
        );
        logger
          ..pair('targetOffsetRaw', target)
          ..pair('targetOffsetClamped', clamped);
        await widget.controller.animateTo(
          clamped.toDouble(),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      } else {
        logger.t('weeklyReport:scroll:noViewport');
        await Scrollable.ensureVisible(
          keyContext,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
          alignment: 0.0,
        );
      }
    } catch (e, st) {
      logger
        ..t('weeklyReport:scroll:error')
        ..pair('error', e.toString())
        ..pair('stack', st.toString());
    }
  }

  void _dismissWeeklyReport({bool keepHighlight = false}) {
    _weeklyReport.dismissCurrent(Markers.userTap);
    setState(() {
      _weeklyEvent = null;
      if (!keepHighlight) {
        _weeklyHighlight = null;
      }
    });
  }

  IconData _iconFor(WeeklyReportIcon icon) {
    switch (icon) {
      case WeeklyReportIcon.chart:
        return CupertinoIcons.chart_bar_alt_fill;
      case WeeklyReportIcon.shield:
        return CupertinoIcons.shield_fill;
      case WeeklyReportIcon.trendUp:
        return CupertinoIcons.arrow_up_right;
      case WeeklyReportIcon.trendDown:
        return CupertinoIcons.arrow_down_right;
    }
  }
}
