import 'package:common/src/shared/ui/blokada_segmented_control.dart';
import 'dart:async';

import 'package:common/src/shared/automation/ids.dart';
import 'package:common/src/shared/navigation.dart' show maxContentWidth, getTopPadding;
import 'package:common/src/shared/ui/haptics.dart';
import 'package:common/src/shared/ui/motion.dart';
import 'package:common/src/features/notification/domain/notification.dart';
import 'package:common/src/shared/ui/minicard/minicard.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/features/weekly/ui/weekly_report_card.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/platform/stats/model.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:mobx/mobx.dart' as mobx;
import 'package:timeago/timeago.dart' as timeago;

import 'package:common/src/features/stats/ui/privacy_pulse_charts.dart';
import 'package:common/src/features/stats/domain/controller.dart';
import 'package:common/src/features/stats/ui/recent_activity.dart';
import 'package:common/src/features/stats/ui/stats_error.dart';
import 'package:common/src/features/stats/ui/top_domains.dart';
import 'package:common/src/features/stats/ui/totalcounter.dart';

/// Privacy Pulse: charts, toplists, recent activity and all-time totals.
/// Everything it shows comes from [StatsController], which also does the
/// fetching; this widget only draws the sections and forwards user actions.
class PrivacyPulseSection extends StatefulWidget {
  final ScrollController controller;
  final ToplistRange? initialRange;

  /// Draws this made-up data instead of the device's, with taps ignored and
  /// no weekly card: the preview shown while activity logging is off.
  final StatsController? sample;

  const PrivacyPulseSection({
    Key? key,
    required this.controller,
    this.initialRange,
    this.sample,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => PrivacyPulseSectionState();
}

class PrivacyPulseSectionState extends State<PrivacyPulseSection> with Logging, Disposables {
  late final _stats = widget.sample ?? Core.get<StatsController>();
  late final _accountStore = Core.get<AccountStore>();
  late final _weeklyReport = Core.get<WeeklyReportActor>();

  WeeklyReportEvent? _weeklyEvent;
  // The card the user just closed, kept on screen while it animates out.
  WeeklyReportEvent? _closingWeeklyEvent;
  WeeklyReportToplistHighlight? _weeklyHighlight;
  final List<mobx.ReactionDisposer> _disposers = [];
  final _topDomainsHeaderKey = GlobalKey();

  ToplistRange get _toplistRange => _stats.range.now;

  bool get _isFreemium {
    return _accountStore.isFreemium;
  }

  @override
  void initState() {
    super.initState();
    disposeLater(_stats.stats.onChange.listen(rebuild));
    disposeLater(_stats.counters.onChange.listen(rebuild));
    disposeLater(_stats.toplists.onChange.listen(rebuild));
    disposeLater(_stats.recent.onChange.listen(rebuild));
    disposeLater(_stats.range.onChange.listen(rebuild));
    disposeLater(_stats.collecting.onChange.listen(rebuild));
    unawaited(_stats.openPulse(Markers.stats, initialRange: widget.initialRange));

    if (widget.sample != null) return;
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
    _stats.closePulse();
    for (final disposer in _disposers) {
      disposer();
    }
    disposeAll();
    super.dispose();
  }

  Future<void> _pullToRefresh() async {
    unawaited(Haptics.light());
    await _stats.refreshPulse(Markers.userTap);
  }

  Future<void> _setToplistRange(ToplistRange range) async {
    await _stats.setRange(Markers.userTap, range);
  }

  void _retry(StatsPart part) {
    unawaited(_stats.retry(Markers.userTap, part));
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
          ignoring: _isFreemium || widget.sample != null,
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
      _buildRecentActivity(),
      const SizedBox(height: 48),
      TotalCounter(stats: _statsData),
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
              _buildRecentActivity(),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            children: [
              TotalCounter(stats: _statsData),
              const SizedBox(height: 24),
              _buildTopDomains(),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildWeeklyCard(BuildContext context) {
    final closing = _closingWeeklyEvent;
    if (_weeklyEvent == null && closing != null) {
      return [
        _WeeklyCardExit(
          key: ValueKey(closing),
          onDone: () {
            if (mounted) setState(() => _closingWeeklyEvent = null);
          },
          child: Column(children: _buildWeeklyCardFor(context, closing)),
        ),
      ];
    }
    final event = _weeklyEvent;
    if (event == null) return const [];
    return _buildWeeklyCardFor(context, event);
  }

  List<Widget> _buildWeeklyCardFor(BuildContext context, WeeklyReportEvent event) {
    return [
      Builder(builder: (context) {
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
          onDismiss: () => _dismissWeeklyReport(animate: true),
        );
      }),
      const SizedBox(height: 16),
    ];
  }

  UiStats get _statsData => _stats.stats.now.data ?? UiStats.empty();

  /// The charts draw both sections: a counters failure first, then stats
  /// that failed with nothing loaded (drawing them would show zeros).
  Widget? _chartsError(StatsSection<PulseCounters> counters) {
    if (counters.isError) return StatsError(onRetry: () => _retry(StatsPart.counters));
    final stats = _stats.stats.now;
    if (stats.isError && stats.data == null) {
      return StatsError(onRetry: () => _retry(StatsPart.stats));
    }
    return null;
  }

  Widget _buildChartsCard(BuildContext context) {
    final counters = _stats.counters.now;
    return MiniCard(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: PrivacyPulseCharts(
          stats: _statsData,
          counters: counters.data?.counters,
          counterDelta: counters.data?.delta,
          statsReady: _stats.stats.now.data != null,
          deltaReady: counters.data?.deltaReady ?? false,
          sparklineSeries: counters.data?.sparkline,
          range: _toplistRange,
          trailing: _buildToplistRangeToggle(context),
          error: _chartsError(counters),
        ),
      ),
    );
  }

  Widget _buildTopDomains() {
    return TopDomains(
      headerKey: _topDomainsHeaderKey,
      highlight: _weeklyHighlight ?? _weeklyEvent?.toplistHighlight,
      range: _toplistRange,
      section: _stats.toplists.now,
      collecting: _stats.collecting.now,
      onRetry: () => _retry(StatsPart.toplists),
    );
  }

  Widget _buildRecentActivity() {
    return RecentActivity(
      section: _stats.recent.now,
      collecting: _stats.collecting.now,
      onRetry: () => _retry(StatsPart.recent),
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
    return BlokadaSegmentedControl<ToplistRange>(
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
                "stats range 24h".i18n,
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
                "stats range 7d".i18n,
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

  /// [animate] shrinks and fades the card out; the toplist tap removes it at
  /// once, because it scrolls to a position measured without the card.
  void _dismissWeeklyReport({bool keepHighlight = false, bool animate = false}) {
    _weeklyReport.dismissCurrent(Markers.userTap);
    setState(() {
      _closingWeeklyEvent = animate ? _weeklyEvent : null;
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

/// Shrinks and fades the closed weekly card, so the content below slides up
/// instead of jumping, then calls [onDone] to remove it. With Reduce Motion
/// it only fades and the space closes at the end.
class _WeeklyCardExit extends StatefulWidget {
  final Widget child;
  final VoidCallback onDone;

  const _WeeklyCardExit({super.key, required this.child, required this.onDone});

  @override
  State<_WeeklyCardExit> createState() => _WeeklyCardExitState();
}

class _WeeklyCardExitState extends State<_WeeklyCardExit> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
    value: 1.0,
  );
  late final _curve = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

  @override
  void initState() {
    super.initState();
    _controller.reverse().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Already closed: no second tap on its buttons.
    final faded = IgnorePointer(child: FadeTransition(opacity: _curve, child: widget.child));
    if (Motion.reduced(context)) return faded;
    return SizeTransition(sizeFactor: _curve, axisAlignment: -1.0, child: faded);
  }
}
