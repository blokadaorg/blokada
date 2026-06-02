import 'dart:async';

import 'package:common/src/app_variants/family/module/device_v3/device.dart';
import 'package:common/src/app_variants/family/module/profile/profile.dart';
import 'package:common/src/app_variants/family/module/schedule/schedule.dart';
import 'package:common/src/app_variants/family/widget/profile/profile_avatar.dart';
import 'package:common/src/app_variants/family/widget/profile/profile_utils.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/shared/ui/common_card.dart';
import 'package:common/src/shared/ui/common_clickable.dart';
import 'package:common/src/shared/ui/common_divider.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

/// Green used for the "active now" cue. Matches the system green the rest of
/// the iOS UI uses for live/affirmative state.
const _activeGreen = Color(0xFF34C759);

/// A standalone Schedule section sitting between the Settings card and the
/// Internet section on Device detail.
///
/// Layout: an uppercase section title + a one-line gray description, then a
/// card holding — in order — a "Use schedule" toggle row, an ordered rule
/// list, and an Add-rule row. The rule list supports drag-to-reorder via
/// [ReorderableListView]; tapping a rule (or "Add rule") triggers the editor
/// sheet via callbacks supplied by the parent.
///
/// The device's default (base) profile lives in the Device-settings card
/// above this section, not here — the rules override it during their windows.
///
/// Stateful so a 1-minute ticker can recompute the "active now" marker (which
/// rule is firing, and until when) from the client-side resolver without a
/// backend round trip.
class ScheduleSection extends StatefulWidget {
  final DeviceTag deviceTag;
  final List<JsonProfile> profiles;
  final ScheduleModel schedule;
  final ValueChanged<bool> onPausedChanged;
  final ValueChanged<int> onRuleTap;
  final VoidCallback onAddRule;
  final void Function(int oldIndex, int newIndex) onReorder;

  /// Optional swipe-to-delete handler for the rule at [index]. Surfaced as
  /// a trailing red action under [Slidable]. When null, the swipe action
  /// is not rendered (the rule is still deletable via the editor sheet's
  /// Delete footer).
  final void Function(int index)? onDeleteRule;

  const ScheduleSection({
    Key? key,
    required this.deviceTag,
    required this.profiles,
    required this.schedule,
    required this.onPausedChanged,
    required this.onRuleTap,
    required this.onAddRule,
    required this.onReorder,
    this.onDeleteRule,
  }) : super(key: key);

  @override
  State<ScheduleSection> createState() => _ScheduleSectionState();
}

class _ScheduleSectionState extends State<ScheduleSection> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Recompute the active-rule marker every minute so the highlighted row
    // and its "until HH:MM" caption stay current as windows open and close,
    // without polling the backend.
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  JsonProfile? _profileForId(String id) {
    for (final p in widget.profiles) {
      if (p.profileId == id) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final schedule = widget.schedule;
    // Client-side mirror of the backend resolver: which rule (if any) is
    // firing right now. Null when paused or outside every window — the
    // Default profile applies and nothing in the list is marked.
    final active = activeRuleForSchedule(schedule, DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text('family schedule section title'.i18n.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w500)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
          child: Text('family schedule section subtitle'.i18n,
              style: TextStyle(color: context.theme.textSecondary)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: CommonCard(
            child: Column(
              children: [
                _buildUseScheduleRow(context),
                const CommonDivider(indent: 0),
                if (schedule.rules.isNotEmpty) ...[
                  _buildRules(context, active),
                  const CommonDivider(indent: 0),
                ],
                _buildAddRuleRow(context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// "Use schedule" as a standard list row with a trailing [CupertinoSwitch],
  /// replacing the Material switch that used to float in the section header.
  ///
  /// Toggle is positive-state: ON = the schedule enforces its rules. The
  /// wire-format / domain field stays `paused`, so both `value` and the
  /// `onChanged` argument are inverted — flip one without the other and the
  /// round trip breaks.
  Widget _buildUseScheduleRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
      child: Row(
        children: [
          Expanded(
            child: Text('family schedule use label'.i18n,
                style: TextStyle(color: context.theme.textPrimary)),
          ),
          CupertinoSwitch(
            key: const Key('schedule_paused_switch'),
            value: !widget.schedule.paused,
            onChanged: (use) => widget.onPausedChanged(!use),
          ),
        ],
      ),
    );
  }

  /// Renders the ordered list of rule rows. When the user drags a handle to
  /// reorder, the parent's `onReorder` callback persists the new order
  /// through `ScheduleActor.saveSchedule`. [active] (if any) is the rule
  /// firing right now; its row gets the "active now" treatment.
  Widget _buildRules(BuildContext context, ActiveRule? active) {
    final schedule = widget.schedule;
    if (schedule.rules.isEmpty) return const SizedBox.shrink();
    return ReorderableListView.builder(
      shrinkWrap: true,
      primary: false,
      buildDefaultDragHandles: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: schedule.rules.length,
      itemBuilder: (context, i) {
        final rule = schedule.rules[i];
        final p = _profileForId(rule.profileId);
        final isActive = active != null && active.ruleIndex == i;
        return _ruleRow(
          key: ValueKey('rule_$i'),
          context: context,
          index: i,
          profile: p,
          rule: rule,
          isActive: isActive,
          activeUntilMinute: isActive ? active.endMinute : null,
        );
      },
      onReorder: widget.onReorder,
    );
  }

  Widget _ruleRow({
    required Key key,
    required BuildContext context,
    required int index,
    required JsonProfile? profile,
    required RuleModel rule,
    required bool isActive,
    required int? activeUntilMinute,
  }) {
    final profileColor = profile == null
        ? null
        : getProfileColorFor(profile.template, profile.displayAlias);
    final profileName =
        profile?.displayAlias.i18n ?? 'family stats label profile unknown'.i18n;

    final row = CommonClickable(
      onTap: () => widget.onRuleTap(index),
      padding: const EdgeInsets.only(top: 12, bottom: 12, left: 8, right: 8),
      child: Row(
        children: [
          // Leading state indicator: green while this rule is firing,
          // transparent otherwise. Kept the same width in both states so
          // toggling active never shifts the row content sideways. Profile
          // identity moved to the avatar + colored name below, so this bar
          // now reads as "active", not "which profile".
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: isActive ? _activeGreen : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          profile == null
              ? Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: context.theme.divider))
              : ProfileAvatar(
                  template: profile.template,
                  displayAlias: profile.displayAlias,
                  size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: profileName,
                        style: TextStyle(
                            color: profileColor ?? context.theme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    TextSpan(
                        text:
                            '  ${daysSummary(rule.weekdays)} · ${windowsSummary(rule.windows)}',
                        style: TextStyle(
                            color: context.theme.textSecondary, fontSize: 13)),
                  ]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (isActive && activeUntilMinute != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'family schedule active now'
                          .i18n
                          .withParams(formatMinuteOfDay(activeUntilMinute)),
                      style: const TextStyle(
                          color: _activeGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ),
          Icon(Icons.drag_handle, size: 22, color: context.theme.textSecondary),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, size: 22, color: context.theme.divider),
        ],
      ),
    );
    final body = widget.onDeleteRule == null
        ? row
        : Slidable(
            // The Slidable's own key is required by the package so it
            // can track which row is currently swiped. Distinct from
            // the outer ValueKey ReorderableListView reads.
            key: ValueKey('rule_slidable_$index'),
            endActionPane: ActionPane(
              motion: const BehindMotion(),
              extentRatio: 0.3,
              children: [
                SlidableAction(
                  onPressed: (_) => widget.onDeleteRule!(index),
                  backgroundColor: Colors.red.withOpacity(0.80),
                  foregroundColor: Colors.white,
                  icon: CupertinoIcons.delete,
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                ),
              ],
            ),
            child: row,
          );
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      // Dim the row when the schedule is paused so the user has a visible
      // signal that rules aren't firing. 0.5 matches Cupertino's
      // disabled-tappable opacity. Row stays tappable — edit / reorder /
      // delete still work while paused; the dim is a state cue.
      child: Opacity(
        opacity: widget.schedule.paused ? 0.5 : 1.0,
        child: body,
      ),
    );
  }

  Widget _buildAddRuleRow(BuildContext context) {
    final row = CommonClickable(
      onTap: widget.onAddRule,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Row(
        children: [
          Icon(CupertinoIcons.add, size: 18, color: context.theme.accent),
          const SizedBox(width: 8),
          Text('family schedule add rule'.i18n,
              style: TextStyle(
                  color: context.theme.accent,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
    // Same dim treatment as the rule rows so the whole interactive surface of
    // the card reads as "off" when paused. The Use-schedule and Default rows
    // stay bright: the toggle is how you turn it back on, and the Default
    // profile is what actually applies while paused.
    return Opacity(
      opacity: widget.schedule.paused ? 0.5 : 1.0,
      child: row,
    );
  }
}
