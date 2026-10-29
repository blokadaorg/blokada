import 'package:common/src/core/core.dart';
import 'package:common/src/features/journal/domain/journal.dart';
import 'package:common/src/features/stats/ui/stats_filter.dart';
import 'package:common/src/shared/ui/common_clickable.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:common/src/shared/ui/nav_bar_button.dart';

/// One active, non-default field of the journal filter, and how to reset it.
class StatsFilterChipData {
  final String label;
  final JournalFilter Function(JournalFilter) clear;

  const StatsFilterChipData(this.label, this.clear);
}

/// The chips for every filter field that isn't at its default. The device
/// is left out: v6 narrows the journal to the current device by default.
List<StatsFilterChipData> statsFilterChips(JournalFilter filter) {
  return [
    if (filter.showOnly == JournalFilterType.blocked)
      StatsFilterChipData("activity filter show blocked".i18n,
          (f) => f.updateOnly(showOnly: JournalFilterType.all)),
    if (filter.showOnly == JournalFilterType.passed)
      StatsFilterChipData("activity filter show allowed".i18n,
          (f) => f.updateOnly(showOnly: JournalFilterType.all)),
    if (filter.searchQuery.isNotEmpty)
      StatsFilterChipData(filter.searchQuery, (f) => f.updateOnly(searchQuery: "")),
    if (filter.exactMatch)
      StatsFilterChipData(
          "activity filter exact match".i18n, (f) => f.updateOnly(exactMatch: false)),
    if (!filter.sortNewestFirst)
      StatsFilterChipData(
          "activity filter chip most common".i18n, (f) => f.updateOnly(sortNewestFirst: true)),
  ];
}

/// Removable chips above the activity list naming the active filter.
/// Renders nothing while the filter is at its defaults.
class StatsFilterChips extends StatefulWidget {
  const StatsFilterChips({super.key});

  @override
  State<StatefulWidget> createState() => StatsFilterChipsState();
}

class StatsFilterChipsState extends State<StatsFilterChips> with Disposables {
  late final _filter = Core.get<JournalFilterValue>();

  @override
  void initState() {
    super.initState();
    disposeLater(_filter.onChange.listen(rebuild));
  }

  @override
  void dispose() {
    disposeAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chips = statsFilterChips(_filter.now);
    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: chips.map((chip) => _buildChip(context, chip)).toList(),
      ),
    );
  }

  Widget _buildChip(BuildContext context, StatsFilterChipData chip) {
    final theme = context.theme;
    return Container(
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        color: theme.selection,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              chip.label,
              overflow: TextOverflow.ellipsis,
              style: theme.text.callout.copyWith(color: theme.textPrimary),
            ),
          ),
          Semantics(
            button: true,
            label: "${"universal action clear".i18n} ${chip.label}",
            excludeSemantics: true,
            child: CommonClickable(
              onTap: () => _filter.now = chip.clear(_filter.now),
              padding: const EdgeInsets.all(8),
              tapBorderRadius: BorderRadius.circular(16),
              child: Icon(CupertinoIcons.xmark, size: 14, color: theme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// The journal's Search action. Tinted while a filter is on, so a narrowed
/// list doesn't pass for missing data.
class StatsFilterAction extends StatefulWidget {
  const StatsFilterAction({super.key});

  @override
  State<StatefulWidget> createState() => StatsFilterActionState();
}

class StatsFilterActionState extends State<StatsFilterAction> with Disposables {
  late final _filter = Core.get<JournalFilterValue>();

  @override
  void initState() {
    super.initState();
    disposeLater(_filter.onChange.listen(rebuild));
  }

  @override
  void dispose() {
    disposeAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = statsFilterChips(_filter.now).isNotEmpty;
    return Semantics(
      selected: filtered,
      child: NavBarButton(
        onTap: () {
          showStatsFilterDialog(context, onConfirm: (filter) {
            _filter.now = filter;
          });
        },
        selected: filtered,
        child: Text(
          "universal action search".i18n,
          style: context.theme.linkStyle(
            context.theme.text.barAction.copyWith(fontWeight: filtered ? FontWeight.w600 : null),
            underline: false,
          ),
        ),
      ),
    );
  }
}
