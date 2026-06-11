import 'package:collection/collection.dart';
import 'package:common/src/app_variants/family/module/device_v3/device.dart';
import 'package:common/src/app_variants/family/module/profile/profile.dart';
import 'package:common/src/app_variants/family/module/schedule/schedule.dart';
import 'package:common/src/app_variants/family/widget/profile/profile_avatar.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/shared/ui/back_title_nav_bar.dart';
import 'package:common/src/shared/ui/common_card.dart';
import 'package:common/src/shared/ui/common_clickable.dart';
import 'package:common/src/shared/ui/dialog.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Modal sheet for creating or editing a single [RuleModel].
///
/// Variant A from the spec: profile chip row + day preset chips + 7 day
/// toggles + compact times list (soft cap 4 windows + wraparound hint).
/// New rules seed sensible defaults (first profile, Mon-Fri, 09:00-17:00)
/// so the user can save immediately without filling every field. [onSave]
/// is invoked with the validated rule; the sheet pops itself before
/// calling [onSave]. [onDelete] is null for new rules and non-null for
/// edit — the delete button is hidden when null.
class RuleEditorSheet extends StatefulWidget {
  final DeviceTag deviceTag;
  /// Display name of the device this rule belongs to. Rendered next to
  /// the AppBar's back chevron so the nav matches the iOS-standard
  /// "back to <previous screen>" convention used by the blocklist view.
  final String deviceName;
  final RuleModel? initialRule;
  final List<JsonProfile> availableProfiles;
  final String deviceBaseProfileId;
  final Future<JsonProfile?> Function()? onAddProfile;
  /// Opens the canonical profile editor for [profile] (rename, blocklists,
  /// safe-search, delete). Resolves with the updated profile when the
  /// editor pops normally (alias and/or blocklists may have changed), or
  /// `null` when the profile was deleted from inside — the sheet uses
  /// that to clear `_profileId` so the Save gate engages. The host owns
  /// the actor interaction so the sheet stays DI-free.
  final Future<JsonProfile?> Function(JsonProfile profile)? onEditProfile;
  /// Long-press / quick-remove action on a profile chip. The host invokes
  /// [DeviceActor.deleteProfile] (with its rule-target guard) and returns
  /// `true` when the delete went through, `false` when it was blocked or
  /// errored — the sheet uses that to drop the chip without confusing
  /// the user when a delete silently fails.
  final Future<bool> Function(JsonProfile profile)? onDeleteProfile;
  final ValueChanged<RuleModel> onSave;
  final VoidCallback? onDelete;

  const RuleEditorSheet({
    Key? key,
    required this.deviceTag,
    required this.deviceName,
    required this.initialRule,
    required this.availableProfiles,
    required this.deviceBaseProfileId,
    required this.onAddProfile,
    required this.onEditProfile,
    required this.onDeleteProfile,
    required this.onSave,
    required this.onDelete,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _RuleEditorSheetState();
}

class _RuleEditorSheetState extends State<RuleEditorSheet> {
  late List<JsonProfile> _availableProfiles;
  late String _profileId;
  // What the rule does: 'filter' (apply [_profileId]) or 'block' (cut all
  // internet, no profile). Drives whether the profile section is shown and
  // whether Save sends a profileId. Mirrors the wire `action` field.
  late String _action;
  late List<int> _weekdays;
  // Chip row scroll bookkeeping. `_chipsOverflow` reflects whether the
  // content extends past the visible area at all; `_chipsAtStart` and
  // `_chipsAtEnd` track which edges are currently flush, so the shader
  // fades only the side that has hidden content — fading a side that's
  // already at the edge looks like a rendering bug instead of an
  // overflow affordance.
  final ScrollController _chipsScroll = ScrollController();
  bool _chipsOverflow = false;
  bool _chipsAtStart = true;
  bool _chipsAtEnd = true;
  late List<TimeWindowModel> _windows;
  String? _error;

  List<JsonProfile> get _eligibleProfiles => _availableProfiles
      .where((p) =>
          p.template != "parent" && p.profileId != widget.deviceBaseProfileId)
      .toList();

  /// The device's base profile, shown in the chip row as a non-selectable
  /// "Standard" anchor so the user can see what their rule profile is
  /// overriding. Kept separate from [_eligibleProfiles] so the save-button
  /// gate and the `_profileId` seed logic keep treating the base as
  /// ineligible (a rule whose profile equals base is a 24/7 no-op).
  JsonProfile? get _baseProfileForDisplay => _availableProfiles
      .firstWhereOrNull((p) => p.profileId == widget.deviceBaseProfileId);

  @override
  void initState() {
    super.initState();
    _availableProfiles = [...widget.availableProfiles];
    _chipsScroll.addListener(_onChipsScrolled);
    final initial = widget.initialRule;
    // 'block' rules carry no profile; everything else (including a null/absent
    // action on legacy rules) is a filter rule.
    _action = initial?.action == 'block' ? 'block' : 'filter';
    if (initial != null) {
      // Legacy data: an existing rule may carry a profileId that points at
      // a profile no longer eligible for rule targets — the device's own
      // base (a 24/7 no-op), a parent-template profile (filtered out
      // because rules deviate from a kid base, not toward a parent), or a
      // profile that has since been deleted. Any of those leaves the chip
      // row with no matching selection, so seeding `_profileId` to the
      // ineligible value would silently re-persist the broken state when
      // the user hits Save. Clearing it routes the rule through the
      // empty-state path so Save stays disabled until an eligible chip is
      // picked.
      final ineligible = _eligibleProfiles
          .every((p) => p.profileId != initial.profileId);
      _profileId = ineligible ? '' : initial.profileId;
      _weekdays = [...initial.weekdays];
      _windows = [...initial.windows];
    } else {
      // Seeds for a brand-new rule. Default profile is the first eligible
      // chip (excludes parent-template profiles and the device's own base —
      // both make no sense for a rule that is meant to *deviate* from base).
      // When no eligible chip exists this stays empty; the Save button gate
      // and the empty-state sublabel handle that case (Task 3).
      final eligible = _eligibleProfiles;
      _profileId = eligible.isEmpty ? '' : eligible.first.profileId;
      _weekdays = const [1, 2, 3, 4, 5];
      _windows = const [TimeWindowModel(startMinute: 540, endMinute: 1020)];
    }
  }

  @override
  void dispose() {
    _chipsScroll.removeListener(_onChipsScrolled);
    _chipsScroll.dispose();
    super.dispose();
  }

  /// Updates the chip-row edge flags so the trailing/leading ShaderMask
  /// fades only the side that has hidden content. Fires on every scroll
  /// frame; the early-return on equal state keeps it from rebuilding
  /// per pixel.
  void _onChipsScrolled() {
    if (!_chipsScroll.hasClients) return;
    final pos = _chipsScroll.position;
    // Half-pixel slop absorbs subpixel rounding so the flag flips
    // cleanly at the actual edge instead of oscillating.
    final atStart = pos.pixels <= 0.5;
    final atEnd = pos.pixels >= pos.maxScrollExtent - 0.5;
    if (atStart == _chipsAtStart && atEnd == _chipsAtEnd) return;
    setState(() {
      _chipsAtStart = atStart;
      _chipsAtEnd = atEnd;
    });
  }

  Future<void> _handleAddProfile() async {
    final cb = widget.onAddProfile;
    if (cb == null) return;
    final p = await cb();
    if (!mounted || p == null) return;
    setState(() {
      _availableProfiles = [..._availableProfiles, p];
      _profileId = p.profileId;
    });
  }

  Future<void> _handleEditProfile(JsonProfile p) async {
    final cb = widget.onEditProfile;
    if (cb == null) return;
    JsonProfile? updated;
    try {
      updated = await cb(p);
    } catch (e, s) {
      // The host shouldn't take down the awaiting chip handler with an
      // unhandled async error, but we don't want to silence the failure
      // either — surface to the user and print so the trail isn't lost.
      // ignore: avoid_print
      print('rule_editor_sheet: edit profile failed: $e\n$s');
      if (mounted) {
        showErrorDialog(context, 'error fetching data'.i18n);
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      if (updated == null) {
        // Profile deleted from inside the editor (or removed via another
        // path while open). Routes through the same local-drop helper
        // the long-press quick-delete uses so the two surfaces stay in
        // lockstep.
        _dropProfileLocally(p);
      } else {
        // Match on the input profileId so a rename (which keeps the id
        // stable) is applied to the right entry even if a future caller
        // chose to wrap/replace the id.
        final original = p.profileId;
        _availableProfiles = _availableProfiles
            .map((it) => it.profileId == original ? updated! : it)
            .toList();
      }
    });
  }

  /// Drop [p] from the local chip row state. Used both when the editor
  /// reports a profile was deleted (`_handleEditProfile` with a null
  /// update) and after a successful long-press quick-delete. Keeping
  /// the two surfaces routed through one helper means a future change
  /// to "what does locally-dropping a profile mean" applies to both.
  void _dropProfileLocally(JsonProfile p) {
    _availableProfiles = _availableProfiles
        .where((it) => it.profileId != p.profileId)
        .toList();
    if (_profileId == p.profileId) _profileId = '';
  }

  /// Called from the destructive action of the chip's anchored menu.
  /// The host owns the actor call and the in-use guard; on a successful
  /// delete we drop the chip and clear `_profileId` if it was selected.
  /// On a guarded refusal (returns false) the chip stays.
  Future<void> _handleDeleteProfile(JsonProfile p) async {
    final cb = widget.onDeleteProfile;
    if (cb == null) return;
    final removed = await cb(p);
    if (!mounted || !removed) return;
    setState(() => _dropProfileLocally(p));
  }

  /// Anchored "Delete profile" popover shown on long-press of a chip.
  /// Branches on the active platform so the visual reads as native
  /// where the app is running: Cupertino primitives on iOS/macOS,
  /// Material's [showMenu] elsewhere. Matches the existing
  /// `showDefaultDialog` convention in shared/ui/dialog.dart.
  void _showChipMenu(
      BuildContext anchorCtx, Offset globalPos, JsonProfile p) {
    final platform = Theme.of(anchorCtx).platform;
    if (platform == TargetPlatform.iOS ||
        platform == TargetPlatform.macOS) {
      _showCupertinoChipMenu(anchorCtx, globalPos, p);
    } else {
      _showMaterialChipMenu(anchorCtx, globalPos, p);
    }
  }

  /// iOS / macOS — CupertinoPopupSurface + CupertinoButton with the
  /// destructive-red treatment, anchored at the press point via an
  /// overlay entry. Sidesteps [CupertinoContextMenu]'s hero-lift
  /// because it conflicts with the parent's setState when the chip's
  /// selection state changes.
  void _showCupertinoChipMenu(
      BuildContext anchorCtx, Offset globalPos, JsonProfile p) {
    final overlay = Overlay.of(anchorCtx);
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    if (overlayBox == null) return;
    final overlaySize = overlayBox.size;
    const menuWidth = 220.0;
    final left = globalPos.dx.clamp(12.0, overlaySize.width - menuWidth - 12);
    final top = (globalPos.dy + 8).clamp(12.0, overlaySize.height - 80);

    late OverlayEntry entry;
    void close() {
      if (entry.mounted) entry.remove();
    }

    entry = OverlayEntry(builder: (_) {
      return Stack(children: [
        // Full-screen tap target that dismisses the popover. opaque so
        // taps outside the surface don't fall through to the editor.
        Positioned.fill(
          child: GestureDetector(
            key: const Key('chip_menu_dismiss'),
            behavior: HitTestBehavior.opaque,
            onTap: close,
          ),
        ),
        Positioned(
          left: left,
          top: top,
          child: Container(
            // Soft drop shadow matches the iOS popover treatment; the
            // CupertinoPopupSurface itself only provides the rounded
            // translucent surface.
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: CupertinoPopupSurface(
              child: SizedBox(
                width: menuWidth,
                child: CupertinoButton(
                  key: const Key('chip_menu_delete'),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  onPressed: () {
                    close();
                    _handleDeleteProfile(p);
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(CupertinoIcons.delete,
                          color: CupertinoColors.destructiveRed, size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'family profile editor delete'.i18n,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: CupertinoColors.destructiveRed,
                              fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ]);
    });
    overlay.insert(entry);
  }

  /// Android (and any non-iOS/macOS platform) — Material's [showMenu]
  /// anchored at the press point. Material idiom: outlined trash icon,
  /// ink ripple, hard elevation shadow, rectangular-rounded corners
  /// from the surrounding [PopupMenuTheme] defaults.
  Future<void> _showMaterialChipMenu(
      BuildContext anchorCtx, Offset globalPos, JsonProfile p) async {
    final overlay =
        Overlay.of(anchorCtx).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(globalPos, globalPos),
      Offset.zero & overlay.size,
    );
    final chose = await showMenu<bool>(
      context: anchorCtx,
      position: position,
      items: [
        PopupMenuItem<bool>(
          key: const Key('chip_menu_delete'),
          value: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.delete_outline,
                  color: Colors.red, size: 20),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  'family profile editor delete'.i18n,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ),
      ],
    );
    if (chose == true) await _handleDeleteProfile(p);
  }

  void _save() {
    final isBlock = _action == 'block';
    final rule = RuleModel(
      // A block rule must not carry a profile id (server + local validate
      // both reject `block` + profile). A filter rule's action stays null on
      // the wire — the model treats absent as filter, matching the api.
      profileId: isBlock ? '' : _profileId,
      weekdays: _weekdays,
      windows: _windows,
      action: isBlock ? 'block' : null,
    );
    try {
      // Mirror server validation locally so the user sees a friendly error
      // instead of waiting for a 400 from the api.
      ScheduleModel(paused: false, rules: [rule]).validate(
        profileIds:
            _availableProfiles.map((p) => p.profileId).toSet(),
      );
    } on ScheduleValidationError catch (e) {
      setState(() => _error = e.message);
      return;
    }
    Navigator.of(context).maybePop();
    widget.onSave(rule);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.initialRule == null
        ? 'family schedule rule editor title new'.i18n
        : 'family schedule rule editor title edit'.i18n;

    // A block rule needs no profile, so it can always save once days/times
    // are valid; a filter rule stays gated until an eligible profile is
    // picked.
    final saveDisabled = _action != 'block' && _profileId.isEmpty;
    return Scaffold(
      // Page bg matches the device-detail screen (bgColor), so the
      // CommonCard panels below read as raised sections, not a flat wash
      // on a single colour.
      backgroundColor: context.theme.bgColor,
      // Body fills the screen behind the glass nav so its BackdropFilter
      // has live content to blur. With this on, MediaQuery.padding.top
      // inside the body equals safe-area-top + the AppBar's preferred
      // height, which is what the ListView padding below uses to keep
      // initial content clear of the nav.
      extendBodyBehindAppBar: true,
      appBar: BackTitleNavBar(
        previousPageTitle: widget.deviceName,
        backKey: const Key('rule_editor_back'),
        title: Text(title,
            style: TextStyle(
                color: context.theme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600)),
        trailing: CommonClickable(
          key: const Key('rule_editor_save'),
          // Pass null when the gate is closed so the press highlight
          // also suppresses — a no-op closure animates the tap and
          // reads as a broken button instead of a disabled one.
          onTap: saveDisabled ? null : _save,
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text('universal action save'.i18n,
              // Keep the action on one line even when the localised label
              // is long (e.g. es "Guardar"); the nav bar sizes the
              // trailing slot to this content rather than wrapping it.
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: TextStyle(
                  color: saveDisabled
                      ? context.theme.divider
                      : context.theme.accent,
                  fontSize: 17,
                  fontWeight: FontWeight.w600)),
        ),
      ),
      body: Builder(builder: (ctx) {
        // padding.top now equals safe-area + AppBar height (because of
        // extendBodyBehindAppBar above). Forwarding it to the ListView
        // keeps the first section clear of the nav while letting the
        // rest scroll under it. padding.bottom is the home-indicator
        // inset (Scaffold has no bottomNavigationBar here so it's just
        // the system safe area) — without it, the trailing delete row
        // / add-window button sit under the indicator on notched
        // iPhones because the outer SafeArea wrapper is gone.
        final mq = MediaQuery.of(ctx);
        return ListView(
          padding: EdgeInsets.only(
              top: mq.padding.top + 4, bottom: mq.padding.bottom),
          children: [
            _buildTargetSection(context),
            // The profile picker only applies to a filter rule; a block rule
            // cuts all internet and carries no profile, so the whole section
            // is hidden when block is selected.
            if (_action != 'block') _buildProfileSection(context),
            _buildDaysSection(context),
            _buildTimesSection(context),
            if (_error != null)
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(24, 12, 24, 12),
                child: Text(_error!,
                    style: const TextStyle(color: Colors.red)),
              ),
            if (widget.onDelete != null) _buildDeleteFooter(context),
            const SizedBox(height: 32),
          ],
        );
      }),
    );
  }

  /// Section frame matching device_section: an uppercase label at
  /// horizontal 24 above a [CommonCard] at horizontal 12 holding [content].
  /// `extraTop` adds breathing room between successive sections; the
  /// first section caller passes 0 to stay tight to the AppBar.
  ///
  /// [description] is optional explanatory text rendered in the gray area
  /// between the label and the card, matching the Schedule section
  /// subtitle and the rest of the settings UI. Brief / footer texts belong
  /// here, not inside the white card.
  Widget _buildSection(BuildContext context,
      {required String label,
      required Widget content,
      Widget? description,
      double extraTop = 16}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: extraTop),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(label.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w500)),
        ),
        if (description != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
            child: DefaultTextStyle.merge(
              style: TextStyle(color: context.theme.textSecondary),
              child: description,
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: CommonCard(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: content,
            ),
          ),
        ),
      ],
    );
  }

  /// Target selector — what the rule does during its window: switch to a
  /// stricter filtering profile, or cut all internet ("No internet" / block).
  /// Two stacked, mutually-exclusive option rows with a leading checkmark on
  /// the active one. Picking "block" hides the profile section and Save sends
  /// `action: block` with no profile; picking "filter" restores the profile
  /// chips. This is the first section, so it owns `extraTop: 0`.
  Widget _buildTargetSection(BuildContext context) {
    return _buildSection(
      context,
      label: 'family schedule rule editor target label'.i18n,
      extraTop: 0,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _targetOption(
            context,
            key: const Key('rule_target_filter'),
            value: 'filter',
            icon: CupertinoIcons.person_crop_circle,
            iconColor: context.theme.accent,
            title: 'family schedule rule editor target filter'.i18n,
            brief: 'family schedule rule editor target filter brief'.i18n,
          ),
          const SizedBox(height: 4),
          _targetOption(
            context,
            key: const Key('rule_target_block'),
            value: 'block',
            icon: CupertinoIcons.nosign,
            iconColor: Colors.red,
            title: 'family schedule rule editor target block'.i18n,
            brief: 'family schedule rule editor target block brief'.i18n,
          ),
        ],
      ),
    );
  }

  Widget _targetOption(
    BuildContext context, {
    required Key key,
    required String value,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String brief,
  }) {
    final selected = _action == value;
    return CommonClickable(
      key: key,
      onTap: () {
        if (_action == value) return;
        setState(() {
          _action = value;
          // Clearing the surfaced error avoids a stale "filter rule without
          // profile" message lingering after the user switches to block.
          _error = null;
        });
      },
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 22, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: TextStyle(
                        color: context.theme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(brief,
                    style: TextStyle(
                        color: context.theme.textSecondary, fontSize: 13)),
              ],
            ),
          ),
          if (selected)
            Icon(CupertinoIcons.checkmark_alt,
                size: 20, color: context.theme.accent),
        ],
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context) {
    final eligible = _eligibleProfiles;
    final base = _baseProfileForDisplay;
    // Section explainers live in the gray area above the card (matching the
    // Schedule section subtitle and the rest of the settings UI), not inside
    // the white card.
    //
    // Override hint — frames the chip row in the user's mental model ("rule
    // profile overrides standard during this window") before they pick. Only
    // rendered when we can name the standard; if the base profile id isn't in
    // the loaded list yet, the sentence with an empty parenthesis would
    // confuse more than it teaches.
    final descriptionLines = <Widget>[
      if (base != null)
        Text('family schedule rule editor override hint'
            .i18n
            .withParams(base.displayAlias.i18n)),
      if (eligible.isEmpty)
        Padding(
          padding: EdgeInsets.only(top: base != null ? 4 : 0),
          child: Text(
              'family schedule rule editor profile empty subtitle'.i18n,
              style: const TextStyle(fontStyle: FontStyle.italic)),
        ),
    ];
    return _buildSection(
      context,
      label: 'family schedule rule editor profile label'.i18n,
      description: descriptionLines.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: descriptionLines),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildChipRow(context, eligible),
          // Edit affordance for the currently-selected chip. Hidden when
          // no eligible chip is selected (rule editor for a brand-new
          // rule with no profiles yet, or a rule pointing at a
          // non-eligible profile like the device base — those have
          // other entry points).
          if (widget.onEditProfile != null)
            ...(() {
              final selected = eligible
                  .firstWhereOrNull((p) => p.profileId == _profileId);
              return selected == null
                  ? const <Widget>[]
                  : [_buildEditSelectedRow(context, selected)];
            }()),
        ],
      ),
    );
  }

  /// Horizontal chip row + trailing `+ New` chip. The device base
  /// profile is named in the override-hint sentence above the chip row
  /// (see [_buildProfileSection]); rendering it as a chip here too just
  /// burns horizontal space the eligible chips can use, so it's omitted.
  /// Wraps the scroll view in a ShaderMask that fades whichever side
  /// has hidden content: leading edge when the row has been scrolled
  /// past its start, trailing edge when more chips remain to the right.
  /// Fading a side that's already flush with the content edge would
  /// dim a visible chip for no reason and read as a rendering bug.
  Widget _buildChipRow(BuildContext context, List<JsonProfile> eligible) {
    final scroll = SingleChildScrollView(
      key: const Key('profile_chip_scroll'),
      scrollDirection: Axis.horizontal,
      controller: _chipsScroll,
      child: Row(
        children: [
          ...eligible.expand((p) {
            final selected = p.profileId == _profileId;
            final chip = ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ProfileAvatar(
                      template: p.template,
                      displayAlias: p.displayAlias,
                      size: 14),
                  const SizedBox(width: 4),
                  Text(p.displayAlias.i18n),
                ],
              ),
              selected: selected,
              onSelected: (_) =>
                  setState(() => _profileId = p.profileId),
            );
            return [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                // Long-press shows a small Material popup menu anchored
                // at the press position with a destructive "Delete
                // profile" action. The chip's own tap (onSelected) still
                // fires for short taps because the long-press recogniser
                // only wins after the iOS-style hold threshold.
                child: GestureDetector(
                  onLongPressStart: widget.onDeleteProfile == null
                      ? null
                      : (details) =>
                          _showChipMenu(context, details.globalPosition, p),
                  child: chip,
                ),
              ),
            ];
          }),
          ActionChip(
            key: const Key('add_profile_chip'),
            label: Text('family schedule rule editor profile new'.i18n),
            onPressed:
                widget.onAddProfile == null ? null : _handleAddProfile,
          ),
        ],
      ),
    );
    final leftFade = _chipsOverflow && !_chipsAtStart;
    final rightFade = _chipsOverflow && !_chipsAtEnd;
    final faded = ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        // Four stops so the gradient can fade either side independently
        // depending on which edge holds hidden content.
        colors: [
          leftFade ? Colors.transparent : Colors.black,
          Colors.black,
          Colors.black,
          rightFade ? Colors.transparent : Colors.black,
        ],
        stops: const [0.0, 0.08, 0.92, 1.0],
      ).createShader(bounds),
      blendMode: BlendMode.dstIn,
      child: scroll,
    );
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (n) {
        final overflow = n.metrics.maxScrollExtent > 0;
        if (overflow != _chipsOverflow) {
          // Defer to next frame so we don't setState during the build
          // pass that emitted this notification. Edge flags are
          // recomputed from the current scroll position in both
          // directions of the transition: false→true bootstraps
          // atStart/atEnd from the live metrics so the trailing fade
          // engages on first paint (otherwise the initial-true flags
          // would suppress it until the user scrolls); true→false
          // resets to true so the now-shorter row doesn't keep fading
          // a side that no longer has content behind it.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _chipsOverflow = overflow;
              if (overflow) {
                final pos = n.metrics;
                _chipsAtStart = pos.pixels <= 0.5;
                _chipsAtEnd = pos.pixels >= pos.maxScrollExtent - 0.5;
              } else {
                _chipsAtStart = true;
                _chipsAtEnd = true;
              }
            });
          });
        }
        return false;
      },
      child: (leftFade || rightFade) ? faded : scroll,
    );
  }

  Widget _buildEditSelectedRow(
      BuildContext context, JsonProfile selected) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: CommonClickable(
        key: const Key('edit_selected_profile'),
        onTap: () => _handleEditProfile(selected),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.gear,
                size: 14, color: context.theme.accent),
            const SizedBox(width: 6),
            Text(
                'family schedule rule editor profile edit'
                    .i18n
                    .withParams(selected.displayAlias),
                style: TextStyle(
                    color: context.theme.accent, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildDaysSection(BuildContext context) {
    final preset = presetForWeekdays(_weekdays);
    return _buildSection(
      context,
      label: 'family schedule rule editor days label'.i18n,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _presetChip(
                  context,
                  WeekdayPreset.weekdays,
                  'family schedule rule editor preset weekdays'.i18n,
                  preset,
                  'preset_weekdays'),
              _presetChip(
                  context,
                  WeekdayPreset.weekends,
                  'family schedule rule editor preset weekends'.i18n,
                  preset,
                  'preset_weekends'),
              _presetChip(
                  context,
                  WeekdayPreset.every,
                  'family schedule rule editor preset every'.i18n,
                  preset,
                  'preset_every'),
            ],
          ),
          const SizedBox(height: 12),
          // ISO 1..7 (Mon..Sun) day toggles as a full-width Row of equal
          // Expanded cells. Selection changes fill + text colour only, not
          // cell width, so toggling a day never reflows the row (the old
          // FilterChip version grew on selection because of the checkmark,
          // which made chips jump around). The row always spans the full
          // card width.
          Row(
            children: List.generate(7, (i) {
              final day = i + 1; // 1..7
              final selected = _weekdays.contains(day);
              const labels = [
                'Mon',
                'Tue',
                'Wed',
                'Thu',
                'Fri',
                'Sat',
                'Sun',
              ];
              return Expanded(
                child: Padding(
                  // Inter-cell gutter; halved on the outer edges so the
                  // row sits flush with the card padding.
                  padding: EdgeInsets.only(
                      left: i == 0 ? 0 : 3, right: i == 6 ? 0 : 3),
                  child: CommonClickable(
                    key: Key('day_chip_$day'),
                    onTap: () {
                      setState(() {
                        final set = _weekdays.toSet();
                        if (selected) {
                          set.remove(day);
                        } else {
                          set.add(day);
                        }
                        _weekdays = set.toList()..sort();
                      });
                    },
                    padding: EdgeInsets.zero,
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? context.theme.accent
                            : context.theme.divider.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        labels[i],
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: selected
                              ? Colors.white
                              : context.theme.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _presetChip(BuildContext context, WeekdayPreset target, String label,
      WeekdayPreset current, String keySuffix) {
    return ChoiceChip(
      key: Key(keySuffix),
      label: Text(label),
      selected: current == target,
      onSelected: (_) {
        setState(() {
          if (target == WeekdayPreset.custom) {
            // Custom is the catch-all bucket; keep the user's bespoke
            // selection rather than snapping it to anything synthetic.
            return;
          }
          _weekdays = [...weekdaysForPreset(target)];
        });
      },
    );
  }

  Widget _buildTimesSection(BuildContext context) {
    final atCap = _windows.length >= 4;
    return _buildSection(
      context,
      // Section label keeps the count appended ("Tider · 1 av 4") so
      // the soft cap is visible without crowding the AppBar.
      label:
          '${'family schedule rule editor times label'.i18n} · ${'family schedule rule editor times counter'.i18n.withParams(_windows.length.toString())}',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._windows.asMap().entries.map((e) => _buildTimeRow(
              context, e.key, e.value, _windows.length > 1)),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('times_add_button'),
              onPressed: atCap
                  ? null
                  : () {
                      setState(() {
                        // Sensible default: 30 minutes starting at the
                        // previous window's end (or 09:00 if none). Clamp to
                        // the valid 0..1439 range — wraparound is allowed
                        // for the user to express explicitly via the picker
                        // but isn't auto-introduced here. When the previous
                        // window ends at 23:59 there is no room for a forward
                        // window, so wrap the start to midnight; otherwise a
                        // start==end (zero-length) window would be generated
                        // and rejected by validate() on Save.
                        final start = _windows.isEmpty
                            ? 540
                            : (_windows.last.endMinute >= 1439
                                ? 0
                                : _windows.last.endMinute);
                        final end = _windows.isEmpty
                            ? 570
                            : (start + 30).clamp(0, 1439);
                        _windows = [
                          ..._windows,
                          TimeWindowModel(
                              startMinute: start, endMinute: end),
                        ];
                      });
                    },
              child: Text('family schedule rule editor times add'.i18n),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRow(BuildContext context, int index, TimeWindowModel w,
      bool canDelete) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _timeButton(
                    context,
                    'family schedule rule editor times from'.i18n,
                    w.startMinute, (newMin) {
                  _updateWindow(index, w.copyWithStart(newMin));
                }),
              ),
              Text('—',
                  style: TextStyle(color: context.theme.textSecondary)),
              Expanded(
                child: _timeButton(
                    context,
                    'family schedule rule editor times to'.i18n,
                    w.endMinute, (newMin) {
                  _updateWindow(index, w.copyWithEnd(newMin));
                }),
              ),
              if (canDelete)
                IconButton(
                  key: Key('times_delete_$index'),
                  icon: const Icon(CupertinoIcons.minus_circle,
                      color: Colors.red, size: 20),
                  onPressed: () {
                    setState(() {
                      _windows = [..._windows]..removeAt(index);
                    });
                  },
                ),
            ],
          ),
          if (w.wrapsToNextDay)
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 2),
              child: Text(
                  'family schedule rule editor times wrap'.i18n,
                  style: TextStyle(
                      color: context.theme.textSecondary, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _timeButton(BuildContext context, String label, int minute,
      ValueChanged<int> onChanged) {
    return TextButton(
      onPressed: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime:
              TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
          initialEntryMode: TimePickerEntryMode.input,
        );
        if (picked != null) {
          onChanged(picked.hour * 60 + picked.minute);
        }
      },
      child: Text(formatMinuteOfDay(minute),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
    );
  }

  void _updateWindow(int index, TimeWindowModel updated) {
    setState(() {
      final list = [..._windows];
      list[index] = updated;
      _windows = list;
    });
  }

  Widget _buildDeleteFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: CommonClickable(
        onTap: () {
          Navigator.of(context).maybePop();
          widget.onDelete!();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text('family schedule rule editor delete'.i18n,
              style: const TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }
}
