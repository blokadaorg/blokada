import 'dart:async';
// Pull in only `firstWhereOrNull` from collection — bringing in the
// whole library would shadow dartx's `Iterable.sum()` method used
// further down in this file.
import 'package:collection/collection.dart' show IterableExtension;
import 'package:common/src/shared/ui/dialog.dart';
import 'package:common/src/app_variants/family/widget/device/profile_editor_page.dart';
import 'package:common/src/features/customlist/domain/customlist.dart';
import 'package:common/src/features/filter/domain/filter.dart';
import 'package:common/src/features/modal/domain/modal.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:common/src/shared/ui/common_card.dart';
import 'package:common/src/shared/ui/common_clickable.dart';
import 'package:common/src/shared/ui/common_divider.dart';
import 'package:common/src/shared/ui/common_item.dart';
import 'package:common/src/shared/ui/minicard/header.dart';
import 'package:common/src/shared/ui/minicard/minicard.dart';
import 'package:common/src/features/stats/ui/radial_segment.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/app_variants/family/module/device_v3/device.dart';
import 'package:common/src/app_variants/family/module/family/family.dart';
import 'package:common/src/app_variants/family/module/profile/profile.dart';
import 'package:common/src/app_variants/family/module/schedule/actor.dart';
import 'package:common/src/app_variants/family/module/schedule/schedule.dart';
import 'package:common/src/app_variants/family/widget/device/rule_editor_sheet.dart';
import 'package:common/src/app_variants/family/widget/device/schedule_section.dart';
import 'package:common/src/app_variants/family/widget/home/link_device_sheet.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class DeviceSection extends StatefulWidget {
  final DeviceTag tag;

  const DeviceSection({Key? key, required this.tag}) : super(key: key);

  @override
  State<DeviceSection> createState() => DeviceSectionState();
}

class DeviceSectionState extends State<DeviceSection>
    with Logging, Disposables {
  late final _family = Core.get<FamilyActor>();
  late final _device = Core.get<DeviceActor>();
  late final _selectedFilters = Core.get<SelectedFilters>();
  late final _selectedDevice = Core.get<SelectedDeviceTag>();
  late final _custom = Core.get<CustomlistActor>();
  late final _modalWidget = Core.get<CurrentModalWidgetValue>();
  late final _schedule = Core.get<ScheduleActor>();
  late final _profiles = Core.get<ProfileActor>();

  late FamilyDevice device;

  bool built = false;

  @override
  void initState() {
    super.initState();
    disposeLater(_family.devices.onChange.listen(rebuild));
    disposeLater(_selectedFilters.onChange.listen(rebuild));

    _selectedDevice.change(Markers.ui, widget.tag);
  }

  @override
  rebuild(dynamic it) {
    if (!built) return;
    super.rebuild(it);
  }

  @override
  void dispose() {
    _selectedDevice.change(Markers.ui, null);
    disposeAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    built = true;
    device = _family.devices.now.getDevice(widget.tag);
    _custom.setProfileId(device.profile.profileId, Markers.ui);

    return ListView(
      primary: true,
      children: [
        SizedBox(height: getTopPadding(context)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text("family device label statistics".i18n.capitalize(),
              style: const TextStyle(fontWeight: FontWeight.w500)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text("family device brief statistics".i18n,
              style: TextStyle(color: context.theme.textSecondary)),
        ),
        SizedBox(
          //width: width > 600 ? 600 : width,
          width: 600,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: MiniCard(
              onTap: () {
                Navigation.open(Paths.deviceStats, arguments: device);
              },
              child: IgnorePointer(
                ignoring: true,
                child: Column(
                  children: [
                    MiniCardHeader(
                      text: "activity section header".i18n,
                      icon: CupertinoIcons.chart_bar,
                      color: const Color(0xff33c75a),
                      chevronIcon: Icons.chevron_right,
                    ),
                    const SizedBox(height: 4),
                    RadialSegment(stats: device.stats),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text("family device label settings".i18n.capitalize(),
              style: const TextStyle(fontWeight: FontWeight.w500)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text("family device brief settings alt".i18n,
              style: TextStyle(color: context.theme.textSecondary)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: CommonCard(
            child: Column(
              children: [
                Column(
                  children: [
                    CommonItem(
                      onTap: () {
                        showRenameDialog(context, "device", device.device.alias,
                            onConfirm: (name) {
                          _device.renameDevice(
                              device.device, name, Markers.userTap);
                        });
                      },
                      icon: CupertinoIcons.device_phone_portrait,
                      text: "account lease label name".i18n,
                      trailing: Text(device.device.alias,
                          style: TextStyle(color: context.theme.textSecondary)),
                    ),
                    // Profile row removed (issue #292): the device's
                    // single profile is now surfaced as the Default row
                    // inside the Schedule section below. The existing
                    // profile-picker (`showSelectProfileDialog`) is wired
                    // through the section's `onDefaultTap` callback so
                    // tapping Default still opens the same picker.
                    CommonItem(
                      onTap: () {
                        Navigation.open(Paths.deviceFilters, arguments: device);
                      },
                      icon: CupertinoIcons.shield,
                      text: "family stats label blocklists alt".i18n,
                      trailing: Text(
                          "family stats label blocklists count".i18n.withParams(
                              _selectedFilters.present
                                      ?.map((e) => e.options.length)
                                      .sum() ??
                                  0),
                          style: TextStyle(
                            color: context.theme.textSecondary,
                          )),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Schedule section (variant γ) — sits between Settings and Internet.
        // The Default row inside the section is the device's existing
        // single profile; the rule list overrides that default by weekday
        // and time-of-day. See coordinator plan §"Wire format".
        ScheduleSection(
          deviceTag: device.device.deviceTag,
          profiles: _profiles.profiles,
          defaultProfileId: device.device.profileId,
          schedule: device.device.schedule ??
              const ScheduleModel(paused: false, rules: <RuleModel>[]),
          onPausedChanged: (paused) async {
            final current = device.device.schedule ??
                const ScheduleModel(paused: false, rules: <RuleModel>[]);
            try {
              await _schedule.saveSchedule(
                device.device,
                ScheduleActor.setPaused(current, paused),
                Markers.userTap,
              );
            } catch (_) {
              if (context.mounted) {
                showErrorDialog(context, "error fetching data".i18n);
              }
            }
          },
          onDefaultTap: () =>
              showSelectProfileDialog(context, device: device.device),
          onRuleTap: (index) {
            final schedule = device.device.schedule;
            if (schedule == null) return;
            _openRuleEditor(context, device, schedule, editIndex: index);
          },
          onAddRule: () {
            final schedule = device.device.schedule ??
                const ScheduleModel(paused: false, rules: <RuleModel>[]);
            _openRuleEditor(context, device, schedule, editIndex: null);
          },
          onReorder: (oldIndex, newIndex) async {
            final schedule = device.device.schedule;
            if (schedule == null) return;
            try {
              await _schedule.saveSchedule(
                device.device,
                ScheduleActor.reorderRules(schedule, oldIndex, newIndex),
                Markers.userTap,
              );
            } catch (_) {
              if (context.mounted) {
                showErrorDialog(context, "error fetching data".i18n);
              }
            }
          },
          onDeleteRule: (index) async {
            final schedule = device.device.schedule;
            if (schedule == null) return;
            try {
              await _schedule.saveSchedule(
                device.device,
                ScheduleActor.deleteRule(schedule, index),
                Markers.userTap,
              );
            } catch (_) {
              if (context.mounted) {
                showErrorDialog(context, "error fetching data".i18n);
              }
            }
          },
        ),

        // Internet control section
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text("family device label internet".i18n.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w500)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text("family device brief internet".i18n,
              style: TextStyle(color: context.theme.textSecondary)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: CommonCard(
            child: Column(
              children: [
                Column(
                  children: _buildInternetControlOptions(context),
                ),
              ],
            ),
          ),
        ),

        // Bottom links
        const SizedBox(height: 6),
        device.thisDevice
            ? Container()
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: CommonClickable(
                  onTap: () {
                    _modalWidget.change(Markers.userTap,
                        (context) => LinkDeviceSheet(device: device.device));
                  },
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text("family device action link".i18n,
                      style: TextStyle(
                          color: context.theme.textSecondary,
                          fontSize: 16,
                          fontWeight: FontWeight.w500)),
                ),
              ),
        device.thisDevice
            ? Container()
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: CommonClickable(
                  onTap: () {
                    showConfirmDialog(context, device.displayName,
                        onConfirm: () {
                      Navigator.of(context).pop();
                      log(Markers.userTap).trace("deleteDevice", (m) async {
                        await _family.deleteDevice(device.device, m);
                      });
                    });
                  },
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text("family device action delete".i18n,
                      style: const TextStyle(
                          color: Colors.red,
                          fontSize: 16,
                          fontWeight: FontWeight.w500)),
                ),
              ),
        const SizedBox(height: 48),
      ],
    );
  }

  List<Widget> _buildInternetControlOptions(BuildContext context) {
    onChanged(JsonDeviceMode? value) {
      if (value == null) return;
      log(Markers.userTap)
          .i("changing device mode ${device.device.deviceTag} to $value");
      _device.changeDeviceMode(device.device, value, Markers.userTap);
    }

    return [
      _buildInternetControlOption(
          context,
          JsonDeviceMode.on,
          "family device label internet on".i18n,
          "family device brief internet on".i18n,
          onChanged),
      const CommonDivider(indent: 0),
      _buildInternetControlOption(
          context,
          JsonDeviceMode.off,
          "family device label internet off".i18n,
          "family device brief internet off".i18n,
          onChanged),
      const CommonDivider(indent: 0),
      _buildInternetControlOption(
          context,
          JsonDeviceMode.blocked,
          "family device label internet block".i18n,
          "family device brief internet block".i18n,
          onChanged),
    ];
  }

  /// Open the rule editor sheet for [device], either creating a new rule
  /// (`editIndex == null`) or editing an existing one at the given index.
  /// Wires the sheet's save / delete callbacks back through
  /// `ScheduleActor.saveSchedule` so each mutation hits the api and
  /// rebuilds the device-detail UI through the existing `onChange` plumbing.
  void _openRuleEditor(BuildContext context, FamilyDevice device,
      ScheduleModel schedule,
      {int? editIndex}) {
    // Present the editor as a full page (rootNavigator push) instead of
    // a Cupertino bottom sheet so it matches the profile editor pushed
    // from inside it. `rootNavigator: true` is load-bearing: the rule
    // editor itself calls `ProfileEditorPage.open` which also pushes on
    // the root navigator — both editors must live on the same scope so
    // dismissals stack correctly. The widget is already a Scaffold with
    // its own header, so it renders identically as a route page.
    // Captured here so the editor's title flows through both `+ New`
    // and the chip-edit row into ProfileEditorPage's back button.
    final ruleEditorTitle = editIndex == null
        ? 'family schedule rule editor title new'.i18n
        : 'family schedule rule editor title edit'.i18n;
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
      builder: (ctx) => RuleEditorSheet(
        deviceTag: device.device.deviceTag,
        deviceName: device.displayName,
        initialRule: editIndex == null ? null : schedule.rules[editIndex],
        availableProfiles: _profiles.profiles,
        deviceBaseProfileId: device.device.profileId,
        onAddProfile: () =>
            _onAddProfileFromRule(ctx, device, ruleEditorTitle),
        onEditProfile: (p) async {
          // The editor uses the actor as source of truth: renames update
          // ProfileActor.profiles in place, deletes remove the entry.
          // After it closes, look the profile up by id: missing → was
          // deleted (from inside the editor or anywhere else); present →
          // possibly renamed, use the fresh value.
          await ProfileEditorPage.open(ctx, p,
              previousPageTitle: ruleEditorTitle);
          return _profiles.profiles
              .firstWhereOrNull((it) => it.profileId == p.profileId);
        },
        onDeleteProfile: (p) async {
          // Long-press → quick remove from the chip row. The actor's
          // checkProfileDeletable guard already blocks deletes that
          // would orphan a rule (on this or any other device); we just
          // surface the typed message via showProfileInUseError.
          try {
            await _device.deleteProfile(Markers.userTap, p);
            return true;
          } on ProfileInUseException catch (e) {
            if (ctx.mounted) showProfileInUseError(ctx, e);
            return false;
          } catch (_) {
            if (ctx.mounted) {
              showErrorDialog(ctx, 'family profile error'.i18n);
            }
            return false;
          }
        },
        onSave: (rule) async {
          final next = editIndex == null
              ? ScheduleActor.addRule(schedule, rule)
              : ScheduleActor.updateRule(schedule, editIndex, rule);
          try {
            await _schedule.saveSchedule(
                device.device, next, Markers.userTap);
          } catch (_) {
            if (context.mounted) {
              showErrorDialog(context, "error fetching data".i18n);
            }
          }
        },
        onDelete: editIndex == null
            ? null
            : () async {
                try {
                  await _schedule.saveSchedule(
                    device.device,
                    ScheduleActor.deleteRule(schedule, editIndex),
                    Markers.userTap,
                  );
                } catch (_) {
                  if (context.mounted) {
                    showErrorDialog(context, "error fetching data".i18n);
                  }
                }
              },
      ),
    ));
  }

  /// Production wiring for the rule editor's `+ New profile` chip.
  ///
  /// Reuses `showRenameDialog` so the dialog copy matches every other
  /// rename surface in the app (`family dialog title new profile` /
  /// `family dialog brief profile`). A Completer bridges the dialog's
  /// callback style back to the awaiting `+ New` chip handler: `onConfirm`
  /// resolves with the new profile (or null on empty name / error) and
  /// `onCancel` resolves with null immediately on a Cancel tap. The 60s
  /// timeout is a backstop only — it covers a barrier-dismiss on platforms
  /// where the dialog can be dismissed without hitting either button.
  Future<JsonProfile?> _onAddProfileFromRule(
      BuildContext context, FamilyDevice device, String previousPageTitle) {
    final completer = Completer<JsonProfile?>();
    showRenameDialog(
      context,
      'profile',
      null,
      onCancel: () {
        if (!completer.isCompleted) completer.complete(null);
      },
      onConfirm: (name) async {
        if (name.isEmpty) {
          if (!completer.isCompleted) completer.complete(null);
          return;
        }
        try {
          final p = await _profiles.addProfile("", name, Markers.userTap);
          if (context.mounted) {
            await ProfileEditorPage.open(context, p,
                previousPageTitle: previousPageTitle);
          }
          // The editor may have renamed (or deleted) the just-created
          // profile. Re-read from the actor so the rule editor's chip
          // reflects the final state. firstWhereOrNull returns null if
          // the user tapped Delete inside the editor — `+ New` then
          // resolves with null and `_handleAddProfile` skips inserting
          // the chip.
          final updated = _profiles.profiles
              .firstWhereOrNull((it) => it.profileId == p.profileId);
          if (!completer.isCompleted) completer.complete(updated);
        } catch (_) {
          if (context.mounted) {
            showErrorDialog(context, "error fetching data".i18n);
          }
          if (!completer.isCompleted) completer.complete(null);
        }
      },
    );
    return completer.future
        .timeout(const Duration(seconds: 60), onTimeout: () => null);
  }

  Widget _buildInternetControlOption(BuildContext context, JsonDeviceMode value,
      String text, String desc, ValueChanged<JsonDeviceMode?> onChanged) {
    return GestureDetector(
      onTap: () {
        onChanged(value);
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 12.0),
        child: Row(
          children: [
            CupertinoRadio(
                value: value,
                groupValue: device.device.mode,
                useCheckmarkStyle: true,
                activeColor: context.theme.accent,
                inactiveColor: context.theme.shadow.withAlpha(127),
                onChanged: onChanged),
            const SizedBox(width: 16),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    color: context.theme.textPrimary,
                    fontSize: 16,
                    //fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.start,
                ),
                Text(
                  desc,
                  style: TextStyle(
                    color: context.theme.textSecondary,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.start,
                ),
              ],
            )),
          ],
        ),
      ),
    );
  }
}

