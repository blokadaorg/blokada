import 'dart:async';

import 'package:common/src/app_variants/v6/module/home/home.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/features/stats/domain/controller.dart';
import 'package:common/src/platform/app/app.dart';
import 'package:common/src/platform/stats/stats.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart' as mobx;

/// "Day 3 of 7 · 1.2K blocked so far" with a thin progress bar, above the
/// counter while a store free trial runs (#460). Draws nothing otherwise.
///
/// It reads the trial when Home comes on screen with protection on, and the
/// blocked count follows the stats refresh the counter drives.
class TrialLine extends StatefulWidget {
  const TrialLine({super.key});

  @override
  State<TrialLine> createState() => _TrialLineState();
}

class _TrialLineState extends State<TrialLine> with Logging, Disposables {
  final _actor = Core.get<TrialHomeActor>();
  final _stats = Core.get<StatsController>();
  final _app = Core.get<AppStore>();

  mobx.ReactionDisposer? _disposeStatusReaction;

  @override
  void initState() {
    super.initState();
    disposeLater(_actor.trial.onChange.listen(rebuild));
    disposeLater(_actor.trialBlocked.onChange.listen(rebuild));
    disposeLater(_stats.stats.onChange.listen(_onStats));
    // HomeActions stays mounted while protection is off: read the trial each
    // time protection comes on.
    _disposeStatusReaction = mobx.reaction<bool>((_) => _app.status.isActive(), (active) {
      if (active) unawaited(_actor.refreshTrial(Markers.ui));
    }, fireImmediately: true);
  }

  /// The stats refresh every 30 s while Home is up. Privacy Pulse refreshes
  /// the same stats while it covers Home: no Home requests then.
  void _onStats(_) {
    rebuild(null);
    if (!mounted || !TickerMode.getNotifier(context).value) return;
    unawaited(_actor.refreshTrialBlocked(Markers.stats));
  }

  @override
  void dispose() {
    _disposeStatusReaction?.call();
    disposeAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trial = _actor.trial.now;
    if (trial == null) return const SizedBox.shrink();

    final theme = context.theme;
    final dayNumber = trial.dayOn(DateTime.now());
    final day = "home trial day".i18n.withParams(dayNumber, trial.length);
    final blocked = _actor.trialBlocked.now;
    // Daily buckets can lag the hourly stats; "0 blocked so far" reads as
    // broken, so a zero shows the day only.
    final text = blocked == null || blocked == 0
        ? day
        : "$day · ${"home trial blocked so far".i18n.withParams(StatsStoreBase.formatCounter(blocked))}";
    // Home scrolls when it runs out of room, but the line sits between the
    // power button and the counter: at accessibility sizes it would wrap to
    // three lines and push the counter off a small screen, so it stops
    // growing at 1.5x.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.5,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center, style: theme.text.footnote.semibold),
            const SizedBox(height: 4),
            SizedBox(
              width: 160,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: dayNumber / trial.length,
                  minHeight: 4,
                  color: theme.accent,
                  backgroundColor: theme.divider,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
