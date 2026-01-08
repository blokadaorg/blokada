import 'package:collection/collection.dart';
import 'package:common/src/features/filter/domain/filter.dart';
import 'package:common/src/features/payment/domain/payment.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:common/src/features/filter/ui/filter.dart';
import 'package:common/src/shared/ui/freemium_screen.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/app_variants/family/module/profile/profile.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/platform/filter/filter.dart';
import 'package:flutter/material.dart';

class V6FiltersSection extends StatefulWidget {
  final bool twoColumns;
  final bool freemium;

  const V6FiltersSection({
    Key? key,
    this.twoColumns = false,
    this.freemium = true,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => V6FiltersSectionState();
}

class V6FiltersSectionState extends State<V6FiltersSection> with Logging, Disposables {
  late final _knownFilters = Core.get<KnownFilters>();
  late final _selectedFilters = Core.get<SelectedFilters>();
  late final _legacy = Core.get<PlatformFilterActor>();
  late final _accountStore = Core.get<AccountStore>();

  late JsonProfile profile;

  bool get _isFreemium {
    return _accountStore.isFreemium;
  }

  @override
  void initState() {
    super.initState();
    disposeLater(_selectedFilters.onChange.listen(rebuild));
  }

  @override
  void dispose() {
    super.dispose();
    disposeAll();
  }

  @override
  Widget build(BuildContext context) {
    final padding = SizedBox(height: getTopPadding(context)) as Widget;
    final filters = widget.twoColumns ? _buildFiltersPerRow(context) : _buildFilters(context);

    return Stack(
      children: [
        IgnorePointer(
          ignoring: _isFreemium,
          child: ListView(primary: true, children: [padding] + filters),
        ),
        (_isFreemium)
            ? FreemiumScreen(
                title: "freemium filters cta header".i18n,
                subtitle: "freemium filters cta desc".i18n,
                placement: Placement.freemiumFilters,
              )
            : Container(),
      ],
    );
  }

  List<Widget> _buildFiltersPerRow(BuildContext context) {
    final filters = _buildFilters(context);
    final rows = <Widget>[];
    for (var i = 0; i < filters.length; i += 2) {
      final row = <Widget>[];
      if (i < filters.length) row.add(Expanded(child: filters[i]));
      if (i + 1 < filters.length) row.add(Expanded(child: filters[i + 1]));
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: row,
      ));
    }
    return rows;
  }

  List<Widget> _buildFilters(BuildContext context) {
    final filters = <Widget>[];
    int i = 0;
    final colors = Core.act.isFamily ? _cardColorsFamily : _cardColorsV6;
    for (final filter in _knownFilters.get()) {
      final color = colors.elementAtOrNull(i++);
      final selected = _selectedFilters.present
              ?.firstWhereOrNull((it) => it.filterName == filter.filterName)
              ?.options ??
          [];
      try {
        filters.add(_buildFilter(context, filter, selected, color: color));
      } catch (e) {
        print("ERROR: Unknown filter from API: '${filter.filterName}' - skipping. Add FilterDecor entry to filter_decor_defaults.dart");
        // Continue processing other filters instead of crashing
      }
    }
    return filters;
  }

  final List<Color?> _cardColorsFamily = [
    const Color(0xFFA9CCFE),
    null,
    const Color(0xFFF4B1C6),
    const Color(0xFFFDB39C),
  ];

  final List<Color?> _cardColorsV6 = [
    const Color(0xFFFFCD8C),
    null,
    const Color(0xFFB1CCF4),
    const Color(0xFFFFA0EC),
    null,
    const Color(0xFFB1F4C8),
    null,
    const Color(0xFFFDB39C),
  ];

  Widget _buildFilter(BuildContext context, Filter filter, List<String> selections,
      {Color? color}) {
    try {
      final texts = filterDecorDefaults.firstWhere((it) => it.filterName == filter.filterName);
      return FilterWidget(
          filter: filter,
          texts: texts,
          selections: selections.toList(), // To not edit in place
          onSelect: (sel, option) {
            _legacy.toggleFilterOption(filter.filterName, option, Markers.userTap);
          },
          bgColor: color);
    } catch (e) {
      throw Exception("Error getting filter decor, filter: ${filter.filterName}: $e");
    }
  }
}
