import 'dart:async';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:common/src/app_variants/family/module/device_v3/device.dart';
import 'package:common/src/app_variants/family/module/profile/profile.dart';
import 'package:common/src/app_variants/family/module/schedule/resolver.dart';
import 'package:common/src/app_variants/family/module/schedule/schedule.dart';
import 'package:common/src/app_variants/family/widget/profile/profile_avatar.dart';
import 'package:common/src/app_variants/family/widget/profile/profile_utils.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/shared/ui/common_card.dart';
import 'package:common/src/shared/ui/common_clickable.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// The two timed-override modes a parent can apply from the Now section.
///
/// [block] cuts all internet (`mode = blocked`); [pause] turns filtering off so
/// everything is allowed (`mode = off`). Both auto-revert at their chosen
/// expiry server-side; the app reflects the choice optimistically.
enum OverrideKind { block, pause }

/// Green used for the affirmative "filtering on" cue, matching the schedule
/// section's active marker so the device screen reads consistently.
const _filterGreen = Color(0xFF34C759);

/// "Right now" readout on the Device detail screen.
///
/// A single tappable row (from [resolveEffectiveState]) that always answers
/// three things: what the device is doing (filtering with a profile /
/// internet open / internet blocked), which setting caused it (Default
/// profile, a schedule rule, or a manual override), and until when it lasts.
/// Tapping it opens the change-now action sheet (Pause filtering / Block
/// internet, led by Resume while an override runs) which chains into the
/// duration sheet. While a manual override is active, the row carries the
/// red in-control bar — the same bar that otherwise sits on the active
/// schedule rule or the Default profile row.
///
/// Stateful only for the bounded-override countdown: a 1-second ticker runs
/// while `mode_until` is approaching so the caption counts down and the
/// readout flips the instant it passes. Schedule-window boundary flips are
/// driven by the parent [DeviceSection]'s own 1-minute rebuild, so this widget
/// keeps no timer in the default / indefinite-override / schedule states.
class NowSection extends StatefulWidget {
  final JsonDevice device;
  final List<JsonProfile> profiles;

  /// Apply a timed [kind] override. [modeUntil] is the chosen expiry, or null
  /// for "until I turn it back on" (indefinite). Host wires this to
  /// `DeviceActor.changeDeviceMode(mode, modeUntil: …)`.
  final void Function(OverrideKind kind, DateTime? modeUntil) onOverride;

  /// Clear the active override and hand the device back to its schedule /
  /// default. Host wires this to `DeviceActor.resumeDevice`.
  final VoidCallback onResume;

  const NowSection({
    Key? key,
    required this.device,
    required this.profiles,
    required this.onOverride,
    required this.onResume,
  }) : super(key: key);

  @override
  State<NowSection> createState() => _NowSectionState();
}

class _NowSectionState extends State<NowSection> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant NowSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The device (hence its mode / mode_until) may have changed under us;
    // re-evaluate whether a countdown ticker is still needed.
    _syncTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// Run the 1-second rebuild ticker only while a *bounded* override is
  /// active — the sole state whose display (the live countdown, and the flip
  /// back to schedule/default the instant `mode_until` passes) needs second
  /// resolution. An indefinite override, a schedule rule, or the plain default
  /// are static until the parent rebuilds (its 1-minute tick covers
  /// schedule-window boundaries), so a per-second rebuild there would be
  /// wasted work.
  void _syncTicker() {
    final until = resolveEffectiveState(widget.device, DateTime.now()).until;
    final needsTicker = until != null;
    if (needsTicker && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {});
        // Once the bound passes the override is gone; stop ticking until a
        // new bounded override appears.
        _syncTicker();
      });
    } else if (!needsTicker && _ticker != null) {
      _ticker!.cancel();
      _ticker = null;
    }
  }

  JsonProfile? _profileForId(String? id) {
    if (id == null) return null;
    return widget.profiles.firstWhereOrNull((p) => p.profileId == id);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final state = resolveEffectiveState(widget.device, now);
    final overrideActive = state.source == EffectiveSource.manualOverride;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text('family device now label'.i18n.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w500)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
          child: Text('family device now brief'.i18n,
              style: TextStyle(color: context.theme.textSecondary)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: CommonCard(
            child: _buildStatusRow(context, state, now),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Text(
              overrideActive
                  ? 'family device now footer override'.i18n
                  : 'family device now footer'.i18n,
              style: TextStyle(color: context.theme.textSecondary, fontSize: 13)),
        ),
      ],
    );
  }

  /// The readout row: the in-control bar (red while an override outranks
  /// everything, transparent otherwise — the bar then sits on the deciding
  /// row further down the page), a leading avatar/glyph, the "what is
  /// happening" label, the source · until caption, and a trailing chevron.
  /// The whole row is the tap target for the change-now sheet.
  Widget _buildStatusRow(BuildContext context, EffectiveState state, DateTime now) {
    final profile = _profileForId(state.profileId);

    final Color dotColor;
    final String statusLabel;
    switch (state.outcome) {
      case EffectiveOutcome.filter:
        dotColor = _filterGreen;
        statusLabel = 'family device now status filter'
            .i18n
            .withParams(profile?.displayAlias.i18n ?? 'family stats label profile unknown'.i18n);
        break;
      case EffectiveOutcome.allowAll:
        dotColor = context.theme.textSecondary;
        statusLabel = 'family device now status allow'.i18n;
        break;
      case EffectiveOutcome.blocked:
        dotColor = Colors.red;
        statusLabel = 'family device now status blocked'.i18n;
        break;
    }

    final String sourceLabel;
    switch (state.source) {
      case EffectiveSource.manualOverride:
        sourceLabel = 'family device now source override'.i18n;
        break;
      case EffectiveSource.scheduleRule:
        sourceLabel = 'family device now source schedule'.i18n;
        break;
      case EffectiveSource.deviceDefault:
        sourceLabel = 'family device now source default'.i18n;
        break;
    }

    // Until-caption: a bounded override shows its live countdown; a firing
    // schedule rule shows its window end (recurring, so minute precision);
    // the default has no horizon.
    final String? untilCaption;
    switch (state.source) {
      case EffectiveSource.manualOverride:
        untilCaption = state.until == null
            ? 'family device now indefinite'.i18n
            : 'family device now until'.i18n.withParams(_formatCountdown(state.until!, now));
        break;
      case EffectiveSource.scheduleRule:
        final schedule = widget.device.schedule;
        final active = schedule == null ? null : activeRuleForSchedule(schedule, now);
        untilCaption = active == null
            ? null
            : 'family device now until'.i18n.withParams(formatMinuteOfDay(active.endMinute));
        break;
      case EffectiveSource.deviceDefault:
        untilCaption = null;
        break;
    }

    final overrideActive = state.source == EffectiveSource.manualOverride;

    return CommonClickable(
      key: const Key('now_status_row'),
      onTap: () => _showChangeNowSheet(context, overrideActive),
      padding: const EdgeInsets.fromLTRB(12, 14, 8, 14),
      child: Row(
        children: [
          Container(
            key: const Key('now_status_bar'),
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: overrideActive ? Colors.red : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          if (profile != null)
            ProfileAvatar(template: profile.template, displayAlias: profile.displayAlias, size: 22)
          else
            _statusGlyph(context, state.outcome, dotColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  statusLabel,
                  style: TextStyle(
                    color: state.outcome == EffectiveOutcome.filter && profile != null
                        ? getProfileColorFor(profile.template, profile.displayAlias)
                        : context.theme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  untilCaption == null ? sourceLabel : '$sourceLabel · $untilCaption',
                  style: TextStyle(color: context.theme.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 24, color: context.theme.divider),
        ],
      ),
    );
  }

  /// Non-profile leading glyph: a circle-slash for blocked, a globe for the
  /// fully-open "Allow all" state. Kept the same footprint as [ProfileAvatar]
  /// so the row content does not shift when the outcome flips.
  Widget _statusGlyph(BuildContext context, EffectiveOutcome outcome, Color color) {
    final icon = outcome == EffectiveOutcome.blocked ? CupertinoIcons.nosign : CupertinoIcons.globe;
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.16),
      ),
      child: Icon(icon, size: 14, color: color),
    );
  }

  /// First-level action sheet from tapping the readout. Led by Resume while
  /// an override runs (so switching override type doesn't require resuming
  /// first); Pause / Block chain into the duration sheet. Same root-navigator
  /// pop discipline as [_showDurationSheet] — always pop via [sheetContext].
  void _showChangeNowSheet(BuildContext context, bool overrideActive) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) {
        return CupertinoActionSheet(
          title: Text('family device now sheet title'.i18n.withParams(widget.device.alias)),
          message: Text('family device now sheet brief'.i18n),
          actions: <Widget>[
            if (overrideActive)
              CupertinoActionSheetAction(
                key: const Key('now_action_resume'),
                onPressed: () {
                  Navigator.pop(sheetContext);
                  widget.onResume();
                },
                child: Text('family device action resume'.i18n),
              ),
            CupertinoActionSheetAction(
              key: const Key('now_action_pause'),
              onPressed: () {
                Navigator.pop(sheetContext);
                _showDurationSheet(context, OverrideKind.pause);
              },
              child: Text('family device action pause'.i18n),
            ),
            CupertinoActionSheetAction(
              key: const Key('now_action_block'),
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(sheetContext);
                _showDurationSheet(context, OverrideKind.block);
              },
              child: Text('family device action block'.i18n),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheetContext),
            child: Text('universal action cancel'.i18n),
          ),
        );
      },
    );
  }

  /// Cupertino action sheet offering exactly the three durations from the
  /// spec. The chosen [DateTime] (or null for indefinite) is handed back to
  /// the host via `onOverride`.
  void _showDurationSheet(BuildContext context, OverrideKind kind) {
    final isBlock = kind == OverrideKind.block;
    final title = isBlock
        ? 'family device override sheet block title'.i18n
        : 'family device override sheet pause title'.i18n;
    final message = isBlock
        ? 'family device override sheet block brief'.i18n
        : 'family device override sheet pause brief'.i18n;

    // The action sheet lives on the *root* navigator (showCupertinoModalPopup
    // defaults to useRootNavigator: true), while this device screen sits on the
    // family shell's *nested* navigator (FamilyMainScreen's Navigator). Popping
    // via the page `context` would resolve to that nested navigator and tear the
    // device screen down (bouncing back to Home) while leaving the sheet route
    // dangling on the root navigator. Always pop the sheet's *own* route via the
    // builder's `sheetContext` so only the sheet dismisses and the device screen
    // stays put.
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) {
        void pick(DateTime? modeUntil) {
          Navigator.pop(sheetContext);
          widget.onOverride(kind, modeUntil);
        }

        return CupertinoActionSheet(
          title: Text(title),
          message: Text(message),
          actions: <Widget>[
            CupertinoActionSheetAction(
              key: const Key('now_duration_hour'),
              onPressed: () => pick(DateTime.now().add(const Duration(hours: 1))),
              child: Text('family device override duration hour'.i18n),
            ),
            CupertinoActionSheetAction(
              key: const Key('now_duration_morning'),
              onPressed: () => pick(_nextMorning(DateTime.now())),
              child: Text('family device override duration morning'.i18n),
            ),
            CupertinoActionSheetAction(
              key: const Key('now_duration_indefinite'),
              isDestructiveAction: isBlock,
              onPressed: () => pick(null),
              child: Text('family device override duration indefinite'.i18n),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheetContext),
            child: Text('universal action cancel'.i18n),
          ),
        );
      },
    );
  }
}

/// Next local 07:00 strictly after [now]. If it is already past 07:00 today
/// the bound rolls to tomorrow morning; before 07:00 it stays today (a 02:00
/// "until tomorrow morning" sensibly means this same morning's 07:00).
DateTime _nextMorning(DateTime now) {
  final todaySeven = DateTime(now.year, now.month, now.day, 7);
  if (now.isBefore(todaySeven)) return todaySeven;
  final tomorrow = now.add(const Duration(days: 1));
  return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 7);
}

/// Human countdown to [until] from [now]. Under an hour shows "M min"; an hour
/// or more shows the wall-clock end time ("until 21:00") since a long
/// remaining span reads more naturally as a target time than a raw duration.
String _formatCountdown(DateTime until, DateTime now) {
  final remaining = until.difference(now);
  if (remaining.inMinutes < 60) {
    final mins = remaining.inMinutes < 1 ? 1 : remaining.inMinutes;
    return '$mins min';
  }
  final local = until.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}
