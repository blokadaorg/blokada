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
import 'package:common/src/shared/ui/section_label.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/cupertino.dart';

/// The v6 blocklists screen: one required main list and optional extras
/// grouped by what they block. v6 has its own widget so Family keeps its
/// provider cards (FilterWidget) unchanged.
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
    final listsOn = v6ListsOn(selected);
    final main = v6MainBlocklist(selected, pick: BlocklistKey.fromTag(_mainPick.present));
    // v6 always has a list on, so an empty selection means it is not loaded
    // yet. Taps then would save over lists the server has.
    final loading = on.isEmpty;

    final colors = _providerColors(context, filters);
    // Older accounts may have several general lists on. They stay as saved,
    // and show in the summary, until the user picks a main list.
    final stacked = on.where(v6MainBlocklists.contains).length > 1;
    final extras = <BlocklistGroup, List<BlocklistKey>>{};
    for (final key in blocklistKeys(filters)) {
      // General lists are only offered as the main one; they don't stack.
      if (v6MainBlocklists.contains(key)) continue;
      extras.putIfAbsent(v6BlocklistGroup(key), () => []).add(key);
    }

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
      SectionLabel(text: "blocklists main header".i18n),
      if (main == null && !loading)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          child: Text(
            "blocklists main pick".i18n,
            style: context.theme.text.callout.semibold.copyWith(color: context.theme.accent),
          ),
        ),
      const SizedBox(height: 4),
      _group(context, [
        for (final key in v6MainBlocklists)
          if (filters.any(
            (it) =>
                it.filterName == key.filterName &&
                it.options.any((o) => o.optionName == key.optionName),
          ))
            _MainRow(
              name: blocklistName(key, filters),
              brief: blocklistBrief(key),
              color: colors[key.filterName],
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
      ]),
      for (final group in BlocklistGroup.values)
        if (extras[group]?.isNotEmpty ?? false) ...[
          const SizedBox(height: 24),
          SectionLabel(text: group.titleKey.i18n),
          const SizedBox(height: 4),
          _group(context, [
            for (final key in extras[group]!)
              _ExtraRow(
                name: blocklistName(key, filters),
                brief: blocklistBrief(key),
                color: colors[key.filterName],
                selected: on.contains(key),
                // The last list on can't go off: there is no "no blocklists".
                // Safe Search doesn't count as one (see v6ListsOn).
                locked: on.contains(key) && listsOn.every((it) => it == key),
                // Same ids as the old cards, which the smoke suite toggles.
                automationId: _automationId("filter_option", key),
                onChanged: (value) => _legacy.toggleExtraBlocklist(key, value, Markers.userTap),
              ),
          ]),
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

  Widget _group(BuildContext context, List<Widget> rows) {
    return CommonCard(
      child: Column(
        children: [
          for (final (i, row) in rows.indexed) ...[if (i > 0) const CommonDivider(indent: 34), row],
        ],
      ),
    );
  }

  /// Keeps the colours the provider cards had, as a small dot per row.
  Map<FilterName, Color> _providerColors(BuildContext context, List<Filter> filters) {
    final markers = context.theme.markers;
    return {
      for (final (i, filter) in filters.indexed) filter.filterName: markers[i % markers.length],
    };
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
                style: context.theme.text.callout.copyWith(color: context.theme.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                loading ? " " : (main ?? "blocklists main none".i18n),
                style: context.theme.text.title.copyWith(
                  fontWeight: FontWeight.bold,
                  color: main == null ? context.theme.accent : null,
                ),
              ),
              if (extras.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  "+ ${extras.join(", ")}",
                  style: context.theme.text.callout.copyWith(color: context.theme.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The provider's colour, kept small so it reads as a hint, not a tile.
class _Dot extends StatelessWidget {
  final Color? color;

  const _Dot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color ?? context.theme.divider, shape: BoxShape.circle),
    );
  }
}

/// Name and optional one-line trade-off of a list.
class _RowText extends StatelessWidget {
  final String name;
  final String? brief;

  const _RowText({required this.name, required this.brief});

  @override
  Widget build(BuildContext context) {
    final brief = this.brief;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: context.theme.text.body),
        if (brief != null) ...[
          const SizedBox(height: 2),
          Text(
            brief,
            style: context.theme.text.footnote.copyWith(color: context.theme.textSecondary),
          ),
        ],
      ],
    );
  }
}

/// One choice of the main list. Tapping it swaps the main list.
class _MainRow extends StatelessWidget {
  final String name;
  final String? brief;
  final Color? color;
  final bool selected;
  final String automationId;
  final VoidCallback? onTap;

  const _MainRow({
    required this.name,
    required this.brief,
    required this.color,
    required this.selected,
    required this.automationId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        identifier: automationId,
        button: true,
        inMutuallyExclusiveGroup: true,
        selected: selected,
        child: CommonClickable(
          tapBorderRadius: BorderRadius.zero,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          onTap: onTap,
          child: Row(
            children: [
              _Dot(color: color),
              const SizedBox(width: 12),
              Expanded(
                child: _RowText(name: name, brief: brief),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 24,
                child: selected
                    ? Icon(CupertinoIcons.checkmark_alt, size: 22, color: context.theme.accent)
                    : null,
              ),
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
  final Color? color;
  final bool selected;
  final bool locked;
  final String automationId;
  final ValueChanged<bool> onChanged;

  const _ExtraRow({
    required this.name,
    required this.brief,
    required this.color,
    required this.selected,
    required this.locked,
    required this.automationId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          _Dot(color: color),
          const SizedBox(width: 12),
          Expanded(
            child: _RowText(name: name, brief: brief),
          ),
          const SizedBox(width: 8),
          // Id on the switch itself, so automation reads its on/off value.
          MergeSemantics(
            child: Semantics(
              identifier: automationId,
              toggled: selected,
              child: BlokadaSwitch(
                activeColor: context.theme.accent,
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
