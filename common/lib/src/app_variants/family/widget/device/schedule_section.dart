import 'package:common/src/app_variants/family/module/device_v3/device.dart';
import 'package:common/src/app_variants/family/module/profile/profile.dart';
import 'package:common/src/app_variants/family/module/schedule/schedule.dart';
import 'package:common/src/app_variants/family/widget/profile/profile_avatar.dart';
import 'package:common/src/app_variants/family/widget/profile/profile_utils.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/shared/ui/common_card.dart';
import 'package:common/src/shared/ui/common_clickable.dart';
import 'package:common/src/shared/ui/common_divider.dart';
import 'package:common/src/shared/ui/common_item.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

/// Variant γ: a standalone Schedule section sitting between the Settings
/// card and the Internet section on Device detail.
///
/// Renders a Pause toggle in the header, then a card containing the Default
/// row + an ordered rule list + an Add-rule trailing item. The list
/// supports drag-to-reorder via Flutter's [ReorderableListView]; tapping a
/// rule (or "Add rule" / "Default") triggers the editor sheet via callbacks
/// supplied by the parent.
///
/// The Default row reads from / writes to the device's existing top-level
/// `profile_id` — there is no `default_profile_id` on the schedule itself.
/// The caller passes that id in via [defaultProfileId] so the section can
/// resolve the profile chip without reaching into the device store.
class ScheduleSection extends StatelessWidget {
  final DeviceTag deviceTag;
  final List<JsonProfile> profiles;
  final String defaultProfileId;
  final ScheduleModel schedule;
  final ValueChanged<bool> onPausedChanged;
  final VoidCallback onDefaultTap;
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
    required this.defaultProfileId,
    required this.schedule,
    required this.onPausedChanged,
    required this.onDefaultTap,
    required this.onRuleTap,
    required this.onAddRule,
    required this.onReorder,
    this.onDeleteRule,
  }) : super(key: key);

  JsonProfile? _profileForId(String id) {
    for (final p in profiles) {
      if (p.profileId == id) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: Text(
                    'family schedule section title'.i18n.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w500)),
              ),
              // Group the label + Switch into a rounded pill so the
              // control reads as one tappable affordance against the
              // section title rather than two loose elements floating at
              // the right edge.
              Container(
                padding: const EdgeInsets.only(left: 14, right: 6),
                decoration: BoxDecoration(
                  color: context.theme.divider.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('family schedule use label'.i18n,
                        style: TextStyle(
                            color: context.theme.textSecondary,
                            fontSize: 13)),
                    const SizedBox(width: 8),
                    // Toggle label is positive-state ("Use schedule"): ON =
                    // the schedule is enforcing rules, matching Apple's
                    // section-level toggle convention. The wire-format /
                    // domain field stays `paused`, so the parameter to
                    // `onChanged` is named `use` for clarity and inverted
                    // before calling back into the host. Keep value and
                    // onChanged both inverted together — flipping one
                    // without the other breaks the round trip.
                    //
                    // shrinkWrap drops the Switch's default 48pt tap-target
                    // padding so the visible track sits flush inside the
                    // pill instead of floating a few points off its right
                    // edge; the pill box itself stays aligned to the 24pt
                    // content margin shared by the title and subtitle.
                    Theme(
                      data: Theme.of(context).copyWith(
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Switch(
                        key: const Key('schedule_paused_switch'),
                        value: !schedule.paused,
                        onChanged: (use) => onPausedChanged(!use),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
              schedule.paused
                  ? 'family schedule paused hint'.i18n
                  : 'family schedule section subtitle'.i18n,
              style: TextStyle(color: context.theme.textSecondary)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: CommonCard(
            child: Column(
              children: [
                _buildDefaultRow(context),
                if (schedule.rules.isNotEmpty) const CommonDivider(indent: 0),
                _buildRules(context),
                const CommonDivider(indent: 0),
                _buildAddRuleRow(context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultRow(BuildContext context) {
    final p = _profileForId(defaultProfileId);
    return CommonItem(
      onTap: onDefaultTap,
      icon: CupertinoIcons.person_crop_circle,
      text: 'family schedule default row title'.i18n,
      trailing: p == null
          ? Text('family stats label profile unknown'.i18n,
              style: TextStyle(color: context.theme.textSecondary))
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ProfileAvatar(
                    template: p.template,
                    displayAlias: p.displayAlias,
                    size: 18),
                const SizedBox(width: 4),
                Text(p.displayAlias.i18n,
                    style: TextStyle(
                        color: getProfileColorFor(p.template, p.displayAlias))),
              ],
            ),
    );
  }

  /// Renders the ordered list of rule rows. When the user drags a handle to
  /// reorder, the parent's `onReorder` callback persists the new order
  /// through `ScheduleActor.saveSchedule`.
  Widget _buildRules(BuildContext context) {
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
        final profileName =
            p?.displayAlias.i18n ?? 'family stats label profile unknown'.i18n;
        return _ruleRow(
          key: ValueKey('rule_$i'),
          context: context,
          index: i,
          summary: '$profileName · ${daysSummary(rule.weekdays)} · '
              '${windowsSummary(rule.windows)}',
          profileColor: p == null ? null : getProfileColorFor(p.template, p.displayAlias),
        );
      },
      onReorder: onReorder,
    );
  }

  Widget _ruleRow({
    required Key key,
    required BuildContext context,
    required int index,
    required String summary,
    required Color? profileColor,
  }) {
    final row = CommonClickable(
      onTap: () => onRuleTap(index),
      padding: const EdgeInsets.only(top: 14, bottom: 14, left: 8, right: 8),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 32,
            decoration: BoxDecoration(
              color: profileColor ?? context.theme.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(summary,
                style: TextStyle(
                    color: context.theme.textPrimary, fontSize: 14),
                overflow: TextOverflow.ellipsis,
                maxLines: 2),
          ),
          Icon(Icons.drag_handle,
              size: 22, color: context.theme.textSecondary),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right,
              size: 22, color: context.theme.divider),
        ],
      ),
    );
    final body = onDeleteRule == null
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
                  onPressed: (_) => onDeleteRule!(index),
                  backgroundColor: Colors.red.withOpacity(0.80),
                  foregroundColor: Colors.white,
                  icon: CupertinoIcons.delete,
                  borderRadius:
                      const BorderRadius.all(Radius.circular(8)),
                ),
              ],
            ),
            child: row,
          );
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      // Dim the row when the schedule is paused so the user has a
      // visible signal that this rule isn't currently firing. 0.5
      // matches Cupertino's disabled-tappable opacity convention. Row
      // is still tappable — edit / reorder / delete still work while
      // paused, the dim is a state cue, not a hard-disable.
      child: Opacity(
        opacity: schedule.paused ? 0.5 : 1.0,
        child: body,
      ),
    );
  }

  Widget _buildAddRuleRow(BuildContext context) {
    final row = CommonClickable(
      onTap: onAddRule,
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
    // Same dim treatment as the rule rows so the whole interactive
    // surface of the card reads as "off" when paused. The Default row
    // stays bright on purpose: when paused, the Default profile is what
    // actually applies, so it's the only live row in this card.
    return Opacity(
      opacity: schedule.paused ? 0.5 : 1.0,
      child: row,
    );
  }
}
