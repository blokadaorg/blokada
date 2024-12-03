import 'package:collection/collection.dart';
import 'package:common/common/module/filter/filter.dart';
import 'package:common/common/navigation.dart';
import 'package:common/common/widget/filter/filter.dart';
import 'package:common/core/core.dart';
import 'package:common/family/module/profile/profile.dart';
import 'package:common/family/widget/profile/profile_utils.dart';
import 'package:common/v6/widget/tab/tab_bar_compensation.dart';
import 'package:flutter/material.dart';

class FiltersSection extends StatefulWidget {
  final String? profileId;
  final bool primary;
  final bool isHeader;

  const FiltersSection(
      {Key? key,
      required this.profileId,
      required this.isHeader,
      this.primary = true})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => FiltersSectionState();
}

class FiltersSectionState extends State<FiltersSection>
    with Logging, Disposables {
  late final _knownFilters = Core.get<KnownFilters>();
  late final _profiles = Core.get<ProfileActor>();
  late final _selectedFilters = Core.get<SelectedFilters>();

  late JsonProfile profile;

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
    List<Widget> header = [];
    if (!widget.isHeader) {
      profile = _profiles.get(widget.profileId!);
      header = _buildFamilyHeader(context);
    } else {
      header = _buildV6Header(context);
    }

    return ListView(
        primary: widget.primary,
        children: header + _buildFilters(context) + [TapBarCompensation()]
        //_buildFooter(context),
        );
  }

  List<Widget> _buildFamilyHeader(BuildContext context) {
    return [
      SizedBox(height: getTopPadding(context)),
      Column(
        children: [
          const SizedBox(height: 12),
          Icon(
            getProfileIcon(profile.template),
            size: 48,
            color: getProfileColor(profile.template),
          ),
          const SizedBox(height: 8),
          Text(
              "family profile template name"
                  .i18n
                  .withParams(profile.displayAlias.i18n),
              style:
                  const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
        ],
      ),
      const SizedBox(height: 16),
    ];
  }

  List<Widget> _buildV6Header(BuildContext context) {
    return [
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "main tab advanced".i18n,
                style: const TextStyle(
                  fontSize: 34.0, // Mimic large iOS-style header
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12.0),
            ],
          )),
    ];
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
      filters.add(_buildFilter(context, filter, selected, color: color));
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

  Widget _buildFilter(
      BuildContext context, Filter filter, List<String> selections,
      {Color? color}) {
    try {
      final texts = filterDecorDefaults
          .firstWhere((it) => it.filterName == filter.filterName);
      return FilterWidget(
          filter: filter,
          texts: texts,
          selections: selections,
          onSelect: (sel) =>
              _profiles.updateUserChoice(filter, sel, Markers.userTap),
          bgColor: color);
    } catch (e) {
      throw Exception(
          "Error getting filter decor, filter: ${filter.filterName}: $e");
    }
  }

  List<Widget> _buildFooter(BuildContext context) {
    return [
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.all(18.0),
        child: Text("family profile action delete".i18n,
            style: const TextStyle(
                color: Colors.red, fontSize: 16, fontWeight: FontWeight.w500)),
      ),
      const SizedBox(height: 48),
    ];
  }
}
