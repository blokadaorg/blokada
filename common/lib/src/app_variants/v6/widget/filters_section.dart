import 'package:common/src/core/core.dart';
import 'package:common/src/features/filter/domain/filter.dart';
import 'package:common/src/features/settings/ui/settings_item.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/platform/filter/filter.dart';
import 'package:common/src/shared/automation/ids.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:common/src/shared/ui/blokada_switch.dart';
import 'package:common/src/shared/ui/common_card.dart';
import 'package:common/src/shared/ui/common_clickable.dart';
import 'package:common/src/shared/ui/common_divider.dart';
import 'package:common/src/shared/ui/haptics.dart';
import 'package:common/src/shared/ui/motion.dart';
import 'package:common/src/shared/ui/section_label.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/cupertino.dart';

/// The v6 blocklists screen: one required main list, picked from coloured
/// tiles, and optional extras in coloured cards grouped by what they block.
/// v6 has its own widget so Family keeps its provider cards (FilterWidget)
/// unchanged.
///
/// Main and extras are only a grouping here; every change still goes to the
/// server as one flat list through [PlatformFilterActor].
class V6FiltersSection extends StatefulWidget {
  const V6FiltersSection({super.key});

  @override
  State<StatefulWidget> createState() => V6FiltersSectionState();
}

class V6FiltersSectionState extends State<V6FiltersSection> with Logging, Disposables {
  late final _knownFilters = Core.get<KnownFilters>();
  late final _selectedFilters = Core.get<SelectedFilters>();
  late final _mainPick = Core.get<BlocklistMainPick>();
  late final _legacy = Core.get<PlatformFilterActor>();
  late final _accountStore = Core.get<AccountStore>();

  @override
  void initState() {
    super.initState();
    disposeLater(_selectedFilters.onChange.listen(rebuild));
    disposeLater(_mainPick.onChange.listen(rebuild));
    // Reading the pick only loads it; nothing is saved by opening the screen.
    _mainPick.fetch(Markers.ui);
  }

  @override
  void dispose() {
    super.dispose();
    disposeAll();
  }

  @override
  Widget build(BuildContext context) {
    final filters = _knownFilters.get();
    final selected = _selectedFilters.present ?? [];
    final on = selectedBlocklists(selected);
    final main = v6MainBlocklist(selected, pick: BlocklistKey.fromTag(_mainPick.present));
    // v6 always has a list on, so an empty selection means it is not loaded
    // yet. Taps then would save over lists the server has.
    final loading = on.isEmpty;

    // Older accounts may have several general lists on. They stay as saved,
    // and show in the summary, until the user picks a main list.
    final stacked = on.where(v6MainBlocklists.contains).length > 1;
    final extras = <BlocklistGroup, List<BlocklistKey>>{};
    for (final key in blocklistKeys(filters)) {
      // General lists are only offered as the main one; they don't stack.
      if (v6MainBlocklists.contains(key)) continue;
      extras.putIfAbsent(v6BlocklistGroup(key), () => []).add(key);
    }
    final groups = [
      for (final group in BlocklistGroup.values)
        if (extras[group]?.isNotEmpty ?? false) group,
    ];

    final children = <Widget>[
      SizedBox(height: getTopPadding(context)),
      _Summary(
        main: main == null ? null : blocklistName(main, filters),
        extras: on.where((it) => it != main).map((it) => blocklistName(it, filters)).toList(),
        loading: loading,
      ),
      const SizedBox(height: 16),
      CommonCard(
        child: SettingsItem(
          icon: CupertinoIcons.shield_lefthalf_fill,
          text: "family stats title".i18n, // My exceptions
          automationId: AutomationIds.blocklistsExceptions,
          onTap: () => Navigation.open(Paths.settingsExceptions),
        ),
      ),
      const SizedBox(height: 24),
      SectionLabel(text: "blocklists main header pick one".i18n),
      if (main == null && !loading)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          child: Text(
            "blocklists main pick".i18n,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.theme.accent,
            ),
          ),
        ),
      const SizedBox(height: 8),
      _MainGrid(
        tiles: [
          for (final key in v6MainBlocklists)
            if (filters.any(
              (it) =>
                  it.filterName == key.filterName &&
                  it.options.any((o) => o.optionName == key.optionName),
            ))
              _MainTile(
                name: blocklistName(key, filters),
                brief: blocklistBrief(key),
                tint: _providerTints[key.filterName] ?? _coral,
                selected: key == main,
                automationId: _automationId("blocklist_main", key),
                // Tapping the main list again only matters to drop stacked ones.
                onTap: key == main && !stacked
                    ? null
                    : () {
                        Haptics.selection();
                        _legacy.selectMainBlocklist(key, Markers.userTap);
                      },
              ),
        ],
      ),
      if (groups.isNotEmpty) ...[
        const SizedBox(height: 24),
        SectionLabel(text: "blocklists extras header".i18n),
      ],
      for (final (i, group) in groups.indexed) ...[
        SizedBox(height: i == 0 ? 8 : 16),
        _GroupCard(
          title: group.titleKey.i18n,
          tint: _groupTints[i % _groupTints.length],
          rows: [
            for (final key in extras[group]!)
              _ExtraRow(
                name: blocklistName(key, filters),
                brief: blocklistBrief(key),
                selected: on.contains(key),
                // The last list on can't go off: there is no "no blocklists".
                locked: main == null && on.length == 1 && on.contains(key),
                // Same ids as the old cards, which the smoke suite toggles.
                automationId: _automationId("filter_option", key),
                onChanged: (value) => _legacy.toggleExtraBlocklist(key, value, Markers.userTap),
              ),
          ],
        ),
      ],
      const SizedBox(height: 48),
    ];

    return IgnorePointer(
      ignoring: _accountStore.isFreemium || loading,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ListView(primary: true, children: children),
      ),
    );
  }

  String _automationId(String kind, BlocklistKey key) {
    final filterName = _sanitizeAutomationSegment(key.filterName);
    final optionName = _sanitizeAutomationSegment(key.optionName);
    return "automation.$kind.$filterName.$optionName";
  }

  String _sanitizeAutomationSegment(String value) {
    final sanitized = value.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    return sanitized.isEmpty ? "unknown" : sanitized;
  }
}

/// A fill colour with a light and a dark variant. Tiles and cards are filled
/// with it, so the dark variant is deep enough for white text (over 6:1) and
/// the light one pale enough for near-black text.
///
/// Local to this screen rather than in [BlokadaTheme]: these are the
/// blocklists' own identity colours, not app-wide tokens.
class _Tint {
  final Color light;
  final Color dark;

  const _Tint(this.light, this.dark);

  Color of(BuildContext context) => context.theme.isDarkTheme() ? dark : light;
}

const _orange = _Tint(Color(0xFFFFCD8C), Color(0xFF7A5A2C));
const _blue = _Tint(Color(0xFFB1CCF4), Color(0xFF3B5276));
const _pink = _Tint(Color(0xFFFFA0EC), Color(0xFF74386A));
const _coral = _Tint(Color(0xFFFDB39C), Color(0xFF7A4434));
const _green = _Tint(Color(0xFFB1F4C8), Color(0xFF2F6A47));

/// One colour per provider, so a provider keeps its colour. Fixed by name:
/// the old palette went by the api's filter order, which could recolour a
/// provider whenever that order changed.
const _providerTints = {"oisd": _orange, "stevenblack": _blue, "1hosts": _green, "hblock": _pink};

/// Extras cards cycle these, in the order of the approved design.
const _groupTints = [_orange, _blue, _pink, _coral, _green];

/// Text on a tint: near-black on the light tints, white on the dark ones.
Color _onTint(BuildContext context) => context.theme.textPrimary;

/// The "on" track of a switch in an extras card. The brand orange nearly
/// vanishes on the light cards' rows (1.5 to 1.8:1), so light mode uses the
/// text colour (over 14:1 on every card). On the dark cards the orange is
/// 5.6:1 or more.
Color _switchOn(BuildContext context) =>
    context.theme.isDarkTheme() ? context.theme.accent : context.theme.textPrimary;

/// Main list tiles, two per row. Rows are built by hand, not with a
/// [GridView], so a tile grows with its text instead of being clipped to a
/// fixed aspect ratio, and both tiles in a row take the taller height.
/// Large text falls back to one column so names don't break mid-word.
class _MainGrid extends StatelessWidget {
  final List<Widget> tiles;

  const _MainGrid({required this.tiles});

  static const _gap = 10.0;

  @override
  Widget build(BuildContext context) {
    final columns = MediaQuery.textScalerOf(context).scale(1) >= 1.5 ? 1 : 2;
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += columns) {
      if (rows.isNotEmpty) rows.add(const SizedBox(height: _gap));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var c = 0; c < columns; c++) ...[
                if (c > 0) const SizedBox(width: _gap),
                Expanded(child: i + c < tiles.length ? tiles[i + c] : const SizedBox()),
              ],
            ],
          ),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }
}

/// One choice of the main list, filled with its provider's colour. The pick
/// shows as a ring and a check badge, so it doesn't rely on colour alone.
/// Tapping it swaps the main list.
class _MainTile extends StatelessWidget {
  final String name;
  final String? brief;
  final _Tint tint;
  final bool selected;
  final String automationId;
  final VoidCallback? onTap;

  const _MainTile({
    required this.name,
    required this.brief,
    required this.tint,
    required this.selected,
    required this.automationId,
    required this.onTap,
  });

  static const _radius = 14.0;
  static const _ring = 2.0;
  static const _minHeight = 84.0;
  static const _padding = EdgeInsets.fromLTRB(12, 10, 8, 12);

  @override
  Widget build(BuildContext context) {
    final fill = tint.of(context);
    final text = _onTint(context);
    final brief = this.brief;
    return MergeSemantics(
      child: Semantics(
        identifier: automationId,
        button: true,
        inMutuallyExclusiveGroup: true,
        selected: selected,
        child: AnimatedContainer(
          duration: Motion.reduced(context) ? Duration.zero : const Duration(milliseconds: 150),
          // Every tile has a ring's width of border, so picking one doesn't
          // shift its text.
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(width: _ring, color: selected ? text : fill),
          ),
          child: CommonClickable(
            onTap: onTap,
            bgColor: fill,
            // The theme's press colour is too faint on the pale tints.
            tapBgColor: Color.alphaBlend(text.withOpacity(0.12), fill),
            tapBorderRadius: BorderRadius.circular(_radius - _ring),
            padding: _padding,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: _minHeight - 2 * _ring - _padding.vertical),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: text),
                        ),
                        if (brief != null) ...[
                          const SizedBox(height: 4),
                          Text(brief, style: TextStyle(fontSize: 11, color: text.withOpacity(0.8))),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Reserved on every tile, so the badge never covers text.
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: selected ? _CheckBadge(color: text, onColor: fill) : null,
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

/// The filled circle with a check that marks the picked main list.
class _CheckBadge extends StatelessWidget {
  final Color color;
  final Color onColor;

  const _CheckBadge({required this.color, required this.onColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(CupertinoIcons.checkmark_alt, size: 14, color: onColor),
    );
  }
}

/// Extras that block the same kind of thing, as one tinted card. The rows sit
/// on a translucent layer of the page colour, so switches and secondary text
/// keep their contrast whatever the tint.
class _GroupCard extends StatelessWidget {
  final String title;
  final _Tint tint;
  final List<Widget> rows;

  const _GroupCard({required this.title, required this.tint, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: tint.of(context), borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.fromLTRB(6, 12, 6, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _onTint(context),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: context.theme.bgColor.withOpacity(0.45),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                for (final (i, row) in rows.indexed) ...[
                  if (i > 0) const CommonDivider(indent: 12),
                  row,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// What is on, so the user doesn't have to scan every group.
class _Summary extends StatelessWidget {
  final String? main;
  final List<String> extras;
  final bool loading;

  const _Summary({required this.main, required this.extras, required this.loading});

  @override
  Widget build(BuildContext context) {
    final main = this.main;
    return MergeSemantics(
      child: Semantics(
        identifier: AutomationIds.blocklistsSummary,
        child: CommonCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "blocklists summary header".i18n,
                style: TextStyle(fontSize: 14, color: context.theme.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                loading ? " " : (main ?? "blocklists main none".i18n),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: main == null ? context.theme.accent : null,
                ),
              ),
              if (extras.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  "+ ${extras.join(", ")}",
                  style: TextStyle(fontSize: 14, color: context.theme.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One optional list, with a switch.
class _ExtraRow extends StatelessWidget {
  final String name;
  final String? brief;
  final bool selected;
  final bool locked;
  final String automationId;
  final ValueChanged<bool> onChanged;

  const _ExtraRow({
    required this.name,
    required this.brief,
    required this.selected,
    required this.locked,
    required this.automationId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final text = _onTint(context);
    final brief = this.brief;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontSize: 15, color: text)),
                if (brief != null) ...[
                  const SizedBox(height: 2),
                  Text(brief, style: TextStyle(fontSize: 12, color: text.withOpacity(0.75))),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Id on the switch itself, so automation reads its on/off value.
          // The label names the list for screen readers, which otherwise
          // hear only "switch, on".
          MergeSemantics(
            child: Semantics(
              identifier: automationId,
              label: name,
              toggled: selected,
              child: BlokadaSwitch(
                activeColor: _switchOn(context),
                value: selected,
                onChanged: locked ? null : onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
