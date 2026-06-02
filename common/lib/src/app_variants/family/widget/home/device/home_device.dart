import 'dart:async';

import 'package:common/src/shared/navigation.dart';
import 'package:common/src/shared/ui/minicard/chart.dart';
import 'package:common/src/shared/ui/minicard/minicard.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/app_variants/family/module/device_v3/device.dart';
import 'package:common/src/app_variants/family/module/family/family.dart';
import 'package:common/src/app_variants/family/module/profile/profile.dart';
import 'package:common/src/app_variants/family/module/schedule/resolver.dart';
import 'package:common/src/app_variants/family/module/schedule/schedule.dart';
import 'package:common/src/app_variants/family/widget/home/device/home_device_header.dart';
import 'package:flutter/material.dart';

class HomeDevice extends StatefulWidget {
  final void Function()? onLongPress;
  final FamilyDevice device;
  final Color color;

  const HomeDevice({
    Key? key,
    this.onLongPress,
    required this.device,
    required this.color,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => HomeDeviceState();
}

class HomeDeviceState extends State<HomeDevice> with TickerProviderStateMixin {
  late final _profiles = Core.get<ProfileActor>();

  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // The card shows the device's effective state (manual override, schedule,
    // else default). Recompute every minute so it flips at window boundaries
    // without a manual refresh, mirroring the Schedule section on Device
    // detail.
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// The i18n key/alias for the chevron label: a manual override label when
  /// present, otherwise the schedule/default profile label (see
  /// [activeCardLabelKey]). Resolved with `.i18n` at the call site.
  String _activeLabelKey() => activeCardLabelKey(
        widget.device.device,
        widget.device.profile,
        _profiles.profiles,
        DateTime.now(),
      );

  _onTap() async {
    _profiles.selectProfile(Markers.userTap, widget.device.profile);

    Navigation.open(Paths.device, arguments: widget.device);
  }

  @override
  Widget build(BuildContext context) {
    final activeLabelKey = _activeLabelKey();
    return GestureDetector(
      onLongPress: widget.onLongPress,
      child: MiniCard(
        onTap: _onTap,
        // outlined: widget.thisDevice,
        outlined: false,
        child: Column(
          children: [
            DeviceCardHeader(
              text: widget.device.displayName,
              iconName: widget.device.device.alias,
              color: widget.color,
              chevronText: activeLabelKey.i18n,
              chevronIcon: Icons.chevron_right,
            ),
            const SizedBox(height: 12),
            ClipRect(
              child: IgnorePointer(
                ignoring: true,
                child: MiniCardChart(stats: widget.device.stats, color: widget.color),
              ),
            ),
            // SizedBox(height: 12),
            // (widget.device.thisDevice)
            //     ? Column(
            //         children: [
            //           // Divider(
            //           //   color: context.theme.divider,
            //           //   height: 1,
            //           //   indent: 4,
            //           //   endIndent: 4,
            //           //   thickness: 0.4,
            //           // ),
            //           Row(
            //             mainAxisAlignment: MainAxisAlignment.end,
            //             children: [
            //               MiniCard(
            //                   // color: context.theme.bgColor,
            //                   //onTap: _handleGuestTap,
            //                   child: SizedBox(
            //                 height: 24,
            //                 width: 24,
            //                 // child: Icon(CupertinoIcons.power),
            //                 child: Icon(CupertinoIcons.power,
            //                     color: context.theme.textSecondary),
            //               )),
            //               SizedBox(width: 8),
            //               MiniCard(
            //                   // color: context.theme.bgColor,
            //                   onTap: _handleGuestTap,
            //                   child: SizedBox(
            //                     height: 24,
            //                     width: 24,
            //                     // child: Icon(CupertinoIcons.lock),
            //                     child: Icon(CupertinoIcons.lock_open,
            //                         color: context.theme.textSecondary),
            //                   )),
            //               //SizedBox(width: 8),
            //               Spacer(),
            //               // MiniCard(
            //               //     //color: context.theme.bgColor,
            //               //     //onTap: _handleGuestTap,
            //               //     child: SizedBox(
            //               //   height: 24,
            //               //   width: 24,
            //               //   // child: Icon(CupertinoIcons.lock_shield_fill),
            //               //   child: Icon(CupertinoIcons.ellipsis,
            //               //       color: context.theme.textSecondary),
            //               // )),
            //             ],
            //           ),
            //         ],
            //       )
            //     : Container(),
          ],
          //footer: "home status detail active".i18n.replaceAll("*", ""),
        ),
      ),
    );
  }
}

/// Pure helper for the home device card: the profile actually filtering the
/// device right now. Returns the [schedule]'s active-rule profile when a rule
/// is firing at [now], otherwise [fallback] (the device default). [fallback] is
/// also returned when there is no schedule, no rule is firing, or the active
/// rule's profile is not present in [profiles] (e.g. a deleted profile, or
/// profiles not loaded yet). Display-only: the schedule itself is resolved by
/// the backend; this just keeps the home label honest about what is active.
JsonProfile activeProfileForCard(
  ScheduleModel? schedule,
  JsonProfile fallback,
  List<JsonProfile> profiles,
  DateTime now,
) {
  if (schedule == null) return fallback;
  final active = activeRuleForSchedule(schedule, now);
  if (active == null) return fallback;
  for (final p in profiles) {
    if (p.profileId == active.rule.profileId) return p;
  }
  return fallback;
}

/// Pure helper for the home device card's chevron label: the i18n key/alias to
/// display for what the device is doing right now. It follows the same
/// precedence as the Device detail "Now" row via [resolveEffectiveState], so
/// manual pause/block overrides outrank schedule/default labels on the home
/// card too. The caller resolves the result with `.i18n`.
String activeCardLabelKey(
  JsonDevice device,
  JsonProfile fallback,
  List<JsonProfile> profiles,
  DateTime now,
) {
  final state = resolveEffectiveState(device, now);
  switch (state.outcome) {
    case EffectiveOutcome.blocked:
      return 'family schedule rule block title';
    case EffectiveOutcome.allowAll:
      return 'family device now status allow';
    case EffectiveOutcome.filter:
      for (final p in profiles) {
        if (p.profileId == state.profileId) return p.displayAlias;
      }
      return fallback.displayAlias;
  }
}
