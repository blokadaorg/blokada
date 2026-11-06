import 'dart:async';

import 'package:common/src/app_variants/v6/module/activation/activation.dart';
import 'package:common/src/app_variants/v6/widget/activation/activation_sheet_parts.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/features/link/domain/link.dart';
import 'package:common/src/features/toast/domain/toast.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'package:common/src/shared/automation/ids.dart';
import 'package:common/src/shared/ui/haptics.dart';
import 'package:common/src/shared/ui/motion.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// The first sheet of the guided activation (#457): what to block, then
/// whether to keep activity logging. Both are asked before the DNS sheet so
/// the setup that follows already blocks what the user picked. Closing it
/// any way hands over to V6ActivationActor, which opens the DNS sheet.
class ActivationIntroSheet extends StatefulWidget {
  const ActivationIntroSheet({super.key});

  @override
  State<ActivationIntroSheet> createState() => ActivationIntroSheetState();
}

class ActivationIntroSheetState extends State<ActivationIntroSheet> {
  late final _activation = Core.get<V6ActivationActor>();

  late Set<ActivationGoal> _goals = _activation.currentGoals();
  bool _askingLogging = false;
  bool _busy = false;

  void _toggle(ActivationGoal goal) {
    // The picks are being saved; a change now would show but not save.
    if (_busy) return;
    unawaited(Haptics.selection());
    setState(() {
      if (!_goals.remove(goal)) _goals.add(goal);
    });
  }

  Future<void> _continue() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _activation.applyGoals(_goals, Markers.userTap);
    } catch (_) {
      // Logged by the trace. The filter save shows its own error and rolls
      // back; the flow goes on, since the lists can be set in Advanced.
    }
    if (!mounted) return;
    if (_activation.asksAboutLogging) {
      setState(() {
        _busy = false;
        _askingLogging = true;
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _answerLogging(bool enable) async {
    if (_busy) return;
    setState(() => _busy = true);
    if (enable) unawaited(Haptics.switchOn());
    try {
      await _activation.answerLogging(enable, Markers.userTap);
    } catch (_) {
      // Logged by the trace. Stay on the question so the user can retry or
      // say no; unanswered, the regular reminder still comes.
      Core.get<ToastActor>().showError("toast save failed".i18n);
      if (mounted) setState(() => _busy = false);
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    return Semantics(
      identifier: AutomationIds.activationIntroSheet,
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
        body: Container(
          color: context.theme.bgColorCard,
          padding: const EdgeInsets.all(16),
          child: AnimatedSwitcher(
            duration: reduced ? Duration.zero : const Duration(milliseconds: 250),
            child: _askingLogging
                ? KeyedSubtree(key: const ValueKey("logging"), child: _buildLogging(context))
                : KeyedSubtree(key: const ValueKey("goals"), child: _buildGoals(context)),
          ),
        ),
      ),
    );
  }

  Widget _buildGoals(BuildContext context) {
    return ActivationSheetLayout(
      body: [
        ActivationHeader("activation goals header".i18n),
        ActivationSecondary("activation goals brief".i18n),
        const SizedBox(height: 16),
        for (final goal in ActivationGoal.values)
          _GoalRow(goal: goal, selected: _goals.contains(goal), onTap: () => _toggle(goal)),
      ],
      footer: [
        ActivationPrimaryButton(
          label: "universal action continue".i18n,
          automationId: AutomationIds.activationGoalsContinue,
          onTap: _busy ? null : _continue,
        ),
      ],
    );
  }

  Widget _buildLogging(BuildContext context) {
    return ActivationSheetLayout(
      body: [
        const SizedBox(height: 24),
        Icon(CupertinoIcons.chart_bar_alt_fill, size: 48, color: context.theme.accent),
        ActivationHeader("activity logging offer header".i18n),
        // The one sentence on what is kept and for how long, shared with the
        // Privacy Pulse offer (#481) so both read the same.
        ActivationSecondary("activity logging offer brief".i18n, center: true),
        const SizedBox(height: 8),
        Center(
          child: GestureDetector(
            onTap: () => Core.get<StageStore>().openLink(LinkId.privacyCloud, Markers.userTap),
            child: Text(
              "activity retention policy".i18n,
              textAlign: TextAlign.center,
              style: context.theme.linkStyle(context.theme.text.callout),
            ),
          ),
        ),
      ],
      footer: [
        ActivationPrimaryButton(
          label: "activity logging action enable".i18n,
          automationId: AutomationIds.activationLoggingEnable,
          onTap: _busy ? null : () => _answerLogging(true),
        ),
        ActivationSecondaryButton(
          label: "activation logging skip".i18n,
          automationId: AutomationIds.activationLoggingSkip,
          onTap: _busy ? null : () => _answerLogging(false),
        ),
      ],
    );
  }
}

/// One goal as a checkable row. Selection is spoken as checked, and the
/// identifier sits in MergeSemantics so it surfaces on iOS.
class _GoalRow extends StatelessWidget {
  final ActivationGoal goal;
  final bool selected;
  final VoidCallback onTap;

  const _GoalRow({required this.goal, required this.selected, required this.onTap});

  static const _icons = {
    ActivationGoal.appAds: CupertinoIcons.game_controller,
    ActivationGoal.trackers: CupertinoIcons.eye_slash,
    ActivationGoal.scams: CupertinoIcons.exclamationmark_shield,
    ActivationGoal.adult: CupertinoIcons.hand_raised,
  };

  static const _ids = {
    ActivationGoal.appAds: AutomationIds.activationGoalAppAds,
    ActivationGoal.trackers: AutomationIds.activationGoalTrackers,
    ActivationGoal.scams: AutomationIds.activationGoalScams,
    ActivationGoal.adult: AutomationIds.activationGoalAdult,
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: MergeSemantics(
        child: Semantics(
          identifier: _ids[goal],
          checked: selected,
          button: true,
          child: Material(
            color: selected ? context.theme.selection : context.theme.panelBackground,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    ExcludeSemantics(child: Icon(_icons[goal], color: context.theme.accent)),
                    const SizedBox(width: 16),
                    Expanded(child: Text(goal.titleKey.i18n, style: context.theme.text.body)),
                    ExcludeSemantics(
                      child: Icon(
                        selected ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
                        color: selected ? context.theme.accent : context.theme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
