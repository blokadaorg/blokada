import 'dart:async';

import 'package:common/src/app_variants/v6/module/activation/activation.dart';
import 'package:common/src/app_variants/v6/widget/activation/activation_sheet_parts.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/features/journal/domain/journal.dart';
import 'package:common/src/features/stats/ui/activity_item.dart';
import 'package:common/src/shared/automation/ids.dart';
import 'package:common/src/shared/ui/common_divider.dart';
import 'package:common/src/shared/ui/motion.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/material.dart';

/// The last step of the guided activation (#457): about a minute of the
/// first blocks right after DNS setup, so the user sees Blokada working
/// instead of an idle home. With activity logging off only the counter is
/// shown, since no requests are kept (see [FirstBlocksMode]).
class FirstBlocksSheet extends StatefulWidget {
  /// How long the sheet keeps refreshing.
  static const liveFor = Duration(seconds: 60);

  /// How often it refreshes. Stats and activity reach the api within
  /// seconds; faster polling would only repeat the same numbers.
  static const refreshEvery = Duration(seconds: 5);

  const FirstBlocksSheet({super.key});

  @override
  State<FirstBlocksSheet> createState() => FirstBlocksSheetState();
}

class FirstBlocksSheetState extends State<FirstBlocksSheet> with Logging {
  late final _activation = Core.get<V6ActivationActor>();
  late final FirstBlocksMode _mode = _activation.firstBlocksMode;

  Timer? _timer;
  bool _live = true;
  bool _polling = false;
  int? _blocked;
  List<UiJournalEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_poll());
    // Counted in ticks rather than wall time, so tests can run the minute.
    final ticks = FirstBlocksSheet.liveFor.inSeconds ~/ FirstBlocksSheet.refreshEvery.inSeconds;
    _timer = Timer.periodic(FirstBlocksSheet.refreshEvery, (timer) {
      if (timer.tick >= ticks) {
        timer.cancel();
        if (mounted) setState(() => _live = false);
      }
      unawaited(_poll());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (_polling) return;
    _polling = true;
    try {
      final snapshot = await _activation.pollFirstBlocks(Markers.stats);
      if (!mounted) return;
      setState(() {
        _blocked = snapshot.blocked;
        _entries = snapshot.entries;
      });
    } catch (e, s) {
      // A missed refresh is not worth an error on this sheet; the next one
      // tries again.
      log(Markers.stats).e(msg: "first blocks refresh failed", err: e, stack: s);
    } finally {
      _polling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = _mode == FirstBlocksMode.feedAndCounter;
    return Semantics(
      identifier: AutomationIds.activationFirstBlocksSheet,
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
        body: Container(
          color: context.theme.bgColorCard,
          padding: const EdgeInsets.all(16),
          child: ActivationSheetLayout(
            body: [
              ActivationHeader("activation first blocks header".i18n),
              ActivationSecondary(
                (feed ? "activation first blocks brief" : "activation first blocks brief counter")
                    .i18n,
                center: true,
              ),
              const SizedBox(height: 24),
              _Counter(blocked: _blocked, live: _live),
              if (feed) ...[const SizedBox(height: 24), _Feed(entries: _entries)],
            ],
            footer: [
              ActivationPrimaryButton(
                label: "universal action done".i18n,
                automationId: AutomationIds.activationFirstBlocksDone,
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The blocked count, with a live dot while the sheet refreshes. The number
/// counts up between refreshes unless Reduce Motion is on.
class _Counter extends StatelessWidget {
  final int? blocked;
  final bool live;

  const _Counter({required this.blocked, required this.live});

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    final value = blocked ?? 0;
    return MergeSemantics(
      child: Semantics(
        identifier: AutomationIds.activationFirstBlocksCounter,
        liveRegion: true,
        child: Column(
          children: [
            TweenAnimationBuilder<int>(
              tween: IntTween(end: value),
              duration: reduced ? Duration.zero : const Duration(milliseconds: 800),
              builder: (context, shown, _) => Text(
                blocked == null ? "–" : "$shown",
                style: context.theme.text.hero.copyWith(color: context.theme.textBlocked),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (live) ...[
                  ExcludeSemantics(
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: context.theme.textBlocked,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  "activation first blocks counter label".i18n,
                  style: context.theme.text.callout.copyWith(color: context.theme.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The latest blocked requests, newest first. Rows don't open details here:
/// the sheet is a moment to watch, and Activity has the full list.
class _Feed extends StatelessWidget {
  final List<UiJournalEntry> entries;

  const _Feed({required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          "activation first blocks waiting".i18n,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.theme.textSecondary),
        ),
      );
    }
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          color: context.theme.bgMiniCard,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            for (var i = 0; i < entries.length; i++) ...[
              ActivityItem(key: ValueKey(entries[i].domainName), entry: entries[i]),
              if (i < entries.length - 1) const CommonDivider(indent: 60),
            ],
          ],
        ),
      ),
    );
  }
}
