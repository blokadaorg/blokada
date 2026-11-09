import 'dart:async';

import 'package:common/src/app_variants/v6/module/home/home.dart';
import 'package:common/src/app_variants/v6/widget/home/actions.dart';
import 'package:common/src/app_variants/v6/widget/home/counter.dart';
import 'package:common/src/app_variants/v6/widget/home/plusbutton.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/features/notification/domain/notification.dart';
import 'package:common/src/features/payment/domain/payment.dart';
import 'package:common/src/features/plan/ui/plan_rows.dart' show formatPlanDate;
import 'package:common/src/features/stats/domain/controller.dart';
import 'package:common/src/features/weekly/ui/weekly_report_card.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/platform/app/app.dart';
import 'package:common/src/platform/stats/stats.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:common/src/shared/ui/anim/reveal.dart';
import 'package:common/src/shared/ui/minicard/minicard.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

/// The area under the power button for the daily Home cohort (#460).
///
/// With protection on it shows, top to bottom: a status line, the trial line
/// during a store trial, today's headline (or the 24 hour counter when there
/// is none) and the Plus bar. Once a paid account has expired it shows what
/// Blokada blocked and one way back (the `winback` placement).
///
/// Every other state is today's Home on purpose, so the two cohorts differ
/// only where the experiment means them to: accounts that never paid and
/// freemium accounts get [HomeActions] unchanged, and with protection off the
/// hint is HomeActions' own.
class DailyHomeActions extends StatefulWidget {
  const DailyHomeActions({super.key});

  @override
  State<DailyHomeActions> createState() => _DailyHomeActionsState();
}

class _DailyHomeActionsState extends State<DailyHomeActions> with Logging {
  final _app = Core.get<AppStore>();
  final _account = Core.get<AccountStore>();

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) {
        final account = _account.account;
        final active = _account.type.isActive();
        final freemium = _account.isFreemium;
        final expired = !active && !freemium && (account?.hasBeenActiveBefore() ?? false);

        if (expired) return const _ExpiredCard();
        if (!active) return const HomeActions();

        final on = _app.status.isActive();
        return SizedBox(
          width: 340,
          child: Stack(
            alignment: AlignmentDirectional.topCenter,
            children: [
              const HomeActions(showCards: false),
              _ActiveCards(visible: on),
            ],
          ),
        );
      },
    );
  }
}

/// The cards shown while protection is on.
class _ActiveCards extends StatefulWidget {
  final bool visible;

  const _ActiveCards({required this.visible});

  @override
  State<_ActiveCards> createState() => _ActiveCardsState();
}

class _ActiveCardsState extends State<_ActiveCards> with Logging, Disposables {
  final _actor = Core.get<DailyHomeActor>();
  final _stats = Core.get<StatsController>();

  @override
  void initState() {
    super.initState();
    disposeLater(_actor.trial.onChange.listen(rebuild));
    disposeLater(_actor.trialBlocked.onChange.listen(rebuild));
    disposeLater(_actor.headline.onChange.listen(rebuild));
    disposeLater(_actor.lastBlockAt.onChange.listen(rebuild));
    disposeLater(_stats.stats.onChange.listen(_onStats));
    if (widget.visible) unawaited(_actor.onActiveShown(Markers.ui));
  }

  @override
  void didUpdateWidget(covariant _ActiveCards oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) unawaited(_actor.onActiveShown(Markers.ui));
  }

  /// The stats refresh every 30 s while Home is up; the headline numbers
  /// and the last block follow them.
  void _onStats(_) {
    rebuild(null);
    if (!widget.visible) return;
    unawaited(_actor.refreshHeadline(Markers.stats));
    unawaited(_actor.refreshLastBlock(Markers.stats));
  }

  @override
  void dispose() {
    disposeAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trial = _actor.trial.now;
    final visible = widget.visible;
    var index = 0;
    return HomeStatsRefresh(
      active: visible,
      child: Column(
        children: [
          Reveal(visible: visible, index: index++, child: _statusLine(context)),
          if (trial != null) ...[
            const SizedBox(height: 6),
            Reveal(visible: visible, index: index++, child: _trialLine(context, trial)),
          ],
          const SizedBox(height: 14),
          Reveal(visible: visible, index: index++, child: _headline(context)),
          const SizedBox(height: 16),
          Reveal(visible: visible, index: index++, child: PlusButton()),
        ],
      ),
    );
  }

  Widget _statusLine(BuildContext context) {
    final lastBlock = _actor.lastBlockAt.now;
    final String text;
    if (lastBlock != null) {
      text = "home status protected last block".i18n.withParams(
        timeago.format(lastBlock, allowFromNow: true),
      );
    } else {
      final blocked = _stats.stats.now.data?.dayBlocked;
      text = blocked == null
          ? "home status protected".i18n
          : "home status protected blocked".i18n.withParams(StatsStoreBase.formatCounter(blocked));
    }
    return Text(
      text,
      textAlign: TextAlign.center,
      style: context.theme.text.callout.copyWith(color: context.theme.textSecondary),
    );
  }

  Widget _trialLine(BuildContext context, TrialProgress trial) {
    final theme = context.theme;
    final day = "home trial day".i18n.withParams(trial.day, trial.length);
    final blocked = _actor.trialBlocked.now;
    final text = blocked == null
        ? day
        : "$day · ${"home trial blocked so far".i18n.withParams(StatsStoreBase.formatCounter(blocked))}";
    return Column(
      children: [
        Text(text, textAlign: TextAlign.center, style: theme.text.footnote.semibold),
        const SizedBox(height: 6),
        SizedBox(
          width: 160,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: trial.day / trial.length,
              minHeight: 4,
              color: theme.accent,
              backgroundColor: theme.divider,
            ),
          ),
        ),
      ],
    );
  }

  Widget _headline(BuildContext context) {
    final headline = _actor.headline.now;
    if (headline == null) return const HomeCounter(driveRefresh: false);
    final theme = context.theme;
    final locale = Localizations.localeOf(context).toString();
    return SizedBox(
      width: double.infinity,
      child: WeeklyReportCard(
        title: _headlineTitle(headline),
        content: Text(
          _headlineBody(headline, locale),
          style: theme.text.callout.copyWith(color: theme.textSecondary, height: 1.3),
        ),
        icon: _headlineIcon(headline),
        iconColor: theme.accent,
        onTap: () {
          log(Markers.userTap).trace("homeDaily:headlineTapped", (m) async {
            log(m).pair("kind", headline.kind.name);
            Navigation.open(Paths.privacyPulse);
          });
        },
      ),
    );
  }
}

String _headlineTitle(HomeHeadline headline) {
  switch (headline.kind) {
    case HomeHeadlineKind.topBlocked:
      return "home headline top blocked title".i18n;
    case HomeHeadlineKind.busiestHour:
      return "home headline busiest hour title".i18n;
    case HomeHeadlineKind.weekly:
      return headline.weekly!.title;
  }
}

String _headlineBody(HomeHeadline headline, String locale) {
  switch (headline.kind) {
    case HomeHeadlineKind.topBlocked:
      return "home headline top blocked body".i18n.withParams(
        headline.domain!,
        StatsStoreBase.formatCounter(headline.count),
      );
    case HomeHeadlineKind.busiestHour:
      final start = headline.hourStart!;
      return "home headline busiest hour body".i18n.withParams(
        StatsStoreBase.formatCounter(headline.count),
        _formatHour(start, locale),
        _formatHour(start.add(const Duration(hours: 1)), locale),
      );
    case HomeHeadlineKind.weekly:
      return headline.weekly!.body;
  }
}

IconData _headlineIcon(HomeHeadline headline) {
  switch (headline.kind) {
    case HomeHeadlineKind.topBlocked:
      return CupertinoIcons.shield_fill;
    case HomeHeadlineKind.busiestHour:
      return CupertinoIcons.clock_fill;
    case HomeHeadlineKind.weekly:
      switch (headline.weekly!.icon) {
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

/// The hour in the locale's clock ("21:00", "9:00 PM"). intl throws for a
/// locale it has no data for; en_US is built in.
String _formatHour(DateTime time, String locale) {
  try {
    return DateFormat.jm(locale).format(time);
  } on ArgumentError {
    return DateFormat.jm("en_US").format(time);
  } on Exception {
    return DateFormat.jm("en_US").format(time);
  }
}

/// A paid subscription ended: when, what Blokada blocked meanwhile, and one
/// way back through the `winback` placement. Freemium accounts never get it;
/// they still have freemium protection and their own upsell.
class _ExpiredCard extends StatefulWidget {
  const _ExpiredCard();

  @override
  State<_ExpiredCard> createState() => _ExpiredCardState();
}

class _ExpiredCardState extends State<_ExpiredCard> with Logging, Disposables {
  final _actor = Core.get<DailyHomeActor>();
  final _account = Core.get<AccountStore>();
  final _payment = Core.get<PaymentActor>();

  @override
  void initState() {
    super.initState();
    disposeLater(_actor.expiredBlocked.onChange.listen(rebuild));
    unawaited(_actor.refreshExpired(Markers.ui));
  }

  @override
  void dispose() {
    disposeAll();
    super.dispose();
  }

  void _resubscribe() {
    log(Markers.userTap).trace("homeDaily:resubscribeTapped", (m) async {
      await _payment.openPaymentScreen(m, placement: Placement.winback);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final endedAt = _account.account?.jsonAccount.getActiveUntil();
    final locale = Localizations.localeOf(context).toString();
    // An unknown end date (year 0) reads worse than no date.
    final header = endedAt == null || endedAt.year < 2000
        ? "home expired header nodate".i18n
        : "home expired header".i18n.withParams(formatPlanDate(endedAt, DateTime.now(), locale));
    final blocked = _actor.expiredBlocked.now;

    return SizedBox(
      width: 340,
      child: Reveal(
        visible: true,
        child: MiniCard(
          outlined: true,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(header, textAlign: TextAlign.center, style: theme.text.headline),
              if (blocked != null && blocked > 0) ...[
                const SizedBox(height: 6),
                Text(
                  "home expired blocked".i18n.withParams(StatsStoreBase.formatCounter(blocked)),
                  textAlign: TextAlign.center,
                  style: theme.text.callout.copyWith(color: theme.textSecondary),
                ),
              ],
              const SizedBox(height: 14),
              MiniCard(
                color: theme.accent,
                onTap: _resubscribe,
                child: Semantics(
                  button: true,
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      "home expired action".i18n,
                      textAlign: TextAlign.center,
                      style: theme.text.body.semibold.copyWith(color: theme.onAccent),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
