import 'package:collection/collection.dart';
import 'dart:ui' as ui;

import 'package:common/src/app_variants/family/module/device_v3/device.dart';
import 'package:common/src/app_variants/family/module/profile/profile.dart';
import 'package:common/src/app_variants/family/widget/filters_section.dart';
import 'package:common/src/app_variants/family/widget/profile/profile_avatar.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/shared/ui/back_title_nav_bar.dart';
import 'package:common/src/shared/ui/common_clickable.dart';
import 'package:common/src/shared/ui/dialog.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Shared "can't delete this profile yet" UI: names the affected devices
/// per [ProfileInUseException.reason] and surfaces via [showErrorDialog].
/// Used by [ProfileEditorPage]'s Delete action and [ProfileDialog]'s
/// swipe-delete catch so the copy stays in lockstep across both surfaces.
void showProfileInUseError(BuildContext context, ProfileInUseException e) {
  if (e.affectedDevices.isEmpty) {
    // Defensive: race where the affected device disappeared between
    // throw and surface. Fall back to the generic delete-failed copy
    // rather than rendering a sentence with a blank where the device
    // name should be.
    showErrorDialog(context, 'family profile error'.i18n);
    return;
  }
  final names = e.affectedDevices.map((d) => d.alias).join(', ');
  final key = e.reason == ProfileInUseReason.deviceDefault
      ? 'family profile error used as default'
      : 'family profile error used by rule';
  showErrorDialog(context, key.i18n.withParams(names));
}

/// Canonical editor for a single profile (name + blocklists + safe-search
/// + delete). Used in three places:
///   - Right after `+ New` in the rule editor (the just-created profile
///     lands here to pick its initial blocklists).
///   - When the rule editor's "Edit <name>" action is tapped on the
///     currently-selected chip.
///   - From `ProfileDialog`'s trailing edit affordance.
///
/// Callers should always use the static [open] helper — it owns the
/// `selectProfile` prerequisite and the navigator-scope details. The
/// page itself pops with no value: Done, back-button, and Delete all
/// call `maybePop()`. The actor is the source of truth, so callers
/// re-read the profile from [ProfileActor] (`firstWhereOrNull`) after
/// the editor closes to learn whether it was renamed, untouched, or
/// deleted.
///
/// [child] is a test seam — production callers omit it and the default
/// [FamilyFiltersSection] is rendered.
class ProfileEditorPage extends StatefulWidget {
  final String profileId;
  /// Label shown next to the back chevron — typically the title of the
  /// screen that opened this editor (e.g. `"Ny regel"`,
  /// `"Redigera regel"`). Falls back to the universal "Back" label when
  /// null, so callers that don't know their own title still get a
  /// readable back-row.
  final String? previousPageTitle;
  final Widget? child;

  const ProfileEditorPage(
      {Key? key,
      required this.profileId,
      this.previousPageTitle,
      this.child})
      : super(key: key);

  /// Single entry point used by `+ New`, the rule-editor's "Edit <name>"
  /// row, and ProfileDialog's edit affordance. Selects [profile] (so the
  /// embedded [FamilyFiltersSection] picks up its filter state) and pushes
  /// the editor onto the root navigator so it covers any hosting modal
  /// dialog or sheet.
  ///
  /// [previousPageTitle] surfaces in the back-button row; pass the
  /// hosting screen's title when known (rule editor passes its own
  /// "New rule" / "Edit rule" label) and leave null otherwise — the
  /// universal "Back" fallback fires.
  ///
  /// Callers should re-fetch the profile from [ProfileActor] after this
  /// future resolves: the actor is the source of truth (renames happen
  /// inline, deletes remove the entry), so a single
  /// `_profiles.profiles.firstWhereOrNull(...)` distinguishes
  /// "still there, possibly renamed" from "deleted from inside or
  /// elsewhere". The page itself doesn't carry a typed pop result.
  static Future<void> open(BuildContext context, JsonProfile profile,
      {String? previousPageTitle}) async {
    final profiles = Core.get<ProfileActor>();
    // Guard against a stale profileId firing `selectProfile`'s global
    // SelectedFilters / _selected mutation when no editor would actually
    // render (e.g. the user tapped Edit on a profile that was deleted
    // from elsewhere in the same session). Caller's actor-driven
    // refresh handles the gone-profile case from here.
    if (!profiles.profiles
        .any((p) => p.profileId == profile.profileId)) {
      return;
    }
    await profiles.selectProfile(Markers.userTap, profile);
    if (!context.mounted) return;
    await Navigator.of(context, rootNavigator: true)
        .push<void>(MaterialPageRoute(
      builder: (_) => ProfileEditorPage(
        profileId: profile.profileId,
        previousPageTitle: previousPageTitle,
      ),
    ));
  }

  @override
  State<ProfileEditorPage> createState() => _ProfileEditorPageState();
}

class _ProfileEditorPageState extends State<ProfileEditorPage> {
  late final _profiles = Core.get<ProfileActor>();
  late final _devices = Core.get<DeviceActor>();

  /// `null` only at the moment the page is opened against a profileId that
  /// already vanished from the account (race or stale id). `build` then
  /// renders a brief blank and a post-frame microtask pops the page so
  /// the caller's `firstWhereOrNull` resolves to null and the chip state
  /// updates accordingly. The page never re-acquires a profile after
  /// init; renames go through [ProfileActor] and update `_profile` in
  /// place via [setState].
  JsonProfile? _profile;

  @override
  void initState() {
    super.initState();
    _profile = _profiles.profiles
        .firstWhereOrNull((it) => it.profileId == widget.profileId);
    if (_profile == null) {
      // Schedule the pop after the first build so the navigator stack
      // is stable. The caller sees the missing profile via the actor.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
  }

  void _rename() {
    final current = _profile!;
    showRenameDialog(context, 'profile', current.displayAlias,
        onConfirm: (newName) async {
      if (newName.trim().isEmpty || newName == current.displayAlias) return;
      try {
        final updated =
            await _profiles.renameProfile(Markers.userTap, current, newName);
        if (mounted) setState(() => _profile = updated);
      } catch (_) {
        if (mounted) showErrorDialog(context, 'family profile error'.i18n);
      }
    });
  }

  Future<void> _confirmDelete() async {
    final current = _profile!;
    // Pre-flight using the actor's own pure guard so the message and
    // the throw stay in lockstep (single source of truth for the
    // deviceDefault vs ruleTarget classification).
    final blocker =
        DeviceActor.checkProfileDeletable(_devices.devices, current);
    if (blocker != null) {
      showProfileInUseError(context, blocker);
      return;
    }
    showDefaultDialog(
      context,
      title: Text('family profile editor delete confirm title'
          .i18n
          .withParams(current.displayAlias)),
      content: (ctx) =>
          Text('family profile editor delete confirm message'.i18n),
      actions: (ctx) => [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(0.0),
            ),
          ),
          child: Text('universal action cancel'.i18n),
        ),
        TextButton(
          onPressed: () async {
            Navigator.of(ctx).pop();
            try {
              await _devices.deleteProfile(Markers.userTap, current);
              if (mounted) Navigator.of(context).maybePop();
            } on ProfileInUseException catch (e) {
              // Race: a referencing device/rule appeared between
              // pre-check and the actor call. The thrown exception
              // carries the affected devices it captured at throw time.
              if (mounted) showProfileInUseError(context, e);
            } catch (_) {
              if (mounted) {
                showErrorDialog(context, 'family profile error'.i18n);
              }
            }
          },
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(0.0),
            ),
          ),
          child: Text('universal action delete'.i18n,
              style: const TextStyle(color: Colors.red)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_profile == null) {
      // Brief blank while the post-frame microtask in initState pops the
      // page. The caller's actor-driven refresh handles the rest.
      return Scaffold(backgroundColor: context.theme.bgColorCard);
    }
    final current = _profile!;
    return Scaffold(
      backgroundColor: context.theme.bgColorCard,
      // Let the body fill the screen behind the nav bar and the bottom
      // dock so the BackdropFilter inside both has live content to blur.
      // Without these, the body is letterboxed between opaque chrome
      // and the glass effect collapses to a flat tint.
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: BackTitleNavBar(
        previousPageTitle: widget.previousPageTitle,
        backKey: const Key('profile_editor_back'),
        // Match the page surface so the glass bar reads as a
        // translucent layer of the body, not a coloured ribbon on top.
        backgroundColor: context.theme.bgColorCard,
        // Title carries the profile name + a small avatar (the only
        // place the alias appears on this screen). FamilyFiltersSection
        // below is given showHeader: false so it doesn't duplicate the
        // alias or restate it as "Profil: <name>". The avatar keeps
        // glance-identification (colored letter or person icon) without
        // the body header. The whole title region is tappable to rename,
        // replacing the previous trailing pencil button.
        title: CommonClickable(
          key: const Key('profile_editor_rename'),
          onTap: _rename,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ProfileAvatar(
                  template: current.template,
                  displayAlias: current.displayAlias,
                  size: 22),
              const SizedBox(width: 8),
              Flexible(
                child: Text(current.displayAlias.i18n,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: context.theme.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        trailing: null,
      ),
      body: widget.child ??
          // Scaffold with extendBodyBehindAppBar:true + extendBody:true
          // populates MediaQuery.padding.top/bottom in the body with the
          // AppBar height and the bottom dock height respectively.
          // Forwarding those as insets means the list keeps scrolling
          // under both glass surfaces while its initial content sits
          // clear of them.
          Builder(builder: (ctx) {
            final mq = MediaQuery.of(ctx);
            return FamilyFiltersSection(
                profileId: widget.profileId,
                primary: true,
                showHeader: false,
                topInset: mq.padding.top,
                bottomInset: mq.padding.bottom);
          }),
      bottomNavigationBar: _buildGlassDock(context),
    );
  }

  /// Floating glass dock: Done primary, Delete secondary. Wraps both in
  /// a single BackdropFilter so content scrolling past the bottom blurs
  /// through, softening the hard contrast between the fixed actions and
  /// the filter list. `extendBody: true` on the Scaffold above lets the
  /// list extend underneath the dock; SafeArea here handles the home
  /// indicator inset so the actions stay clear of it.
  Widget _buildGlassDock(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          color: context.theme.bgColorCard.withOpacity(0.78),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              // Single row: the primary Done CTA takes the remaining width
              // while the destructive delete sits beside it as a compact
              // trailing trash button, instead of stacking a separate
              // full-width Delete row underneath. The outer min-height
              // Column bounds the dock to its content; `bottomNavigationBar`
              // under `extendBody: true` hands down the full screen height,
              // and a bare Row here would stretch the Done CTA to fill it.
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: CommonClickable(
                            key: const Key('blocklists_done_button'),
                            onTap: () => Navigator.of(context).maybePop(),
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: context.theme.accent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                    'family schedule rule editor profile new blocklists done'
                                        .i18n,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        CommonClickable(
                          key: const Key('profile_editor_delete'),
                          onTap: _confirmDelete,
                          tapBorderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(CupertinoIcons.delete,
                                size: 20, color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
