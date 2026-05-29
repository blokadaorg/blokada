import 'package:collection/collection.dart';
import 'package:common/src/features/filter/domain/filter.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:common/src/features/filter/ui/filter.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/app_variants/family/module/profile/profile.dart';
import 'package:common/src/app_variants/family/widget/profile/profile_avatar.dart';
import 'package:flutter/material.dart';

class FamilyFiltersSection extends StatefulWidget {
  final String? profileId;
  final bool primary;
  /// When true (default) renders the big avatar + "Profil: <name>"
  /// title at the top of the list, matching the standalone
  /// device-detail Blocklists route. When the section is embedded
  /// inside ProfileEditorPage the AppBar already carries the profile
  /// name, so the host passes false to drop the duplicate header.
  final bool showHeader;
  /// Extra spacers prepended/appended to the ListView so its content
  /// starts and ends clear of chrome that's drawn over the body —
  /// e.g. a glass AppBar on top and a glass bottom dock. The list
  /// fills the full screen behind that chrome; these insets just
  /// shift its content area so the first card isn't hidden under the
  /// nav bar and the last one isn't masked by the dock.
  final double topInset;
  final double bottomInset;

  const FamilyFiltersSection({
    Key? key,
    required this.profileId,
    this.primary = true,
    this.showHeader = true,
    this.topInset = 0,
    this.bottomInset = 0,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => FamilyFiltersSectionState();
}

class FamilyFiltersSectionState extends State<FamilyFiltersSection>
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
    profile = _profiles.get(widget.profileId!);
    // Embedded uses (profile editor) drop the in-list header; the host's
    // AppBar already shows the profile name. A small top pad keeps the
    // first filter card from butting against the navigation bar.
    // Explicit <Widget> on the alternative branch — otherwise Dart
    // infers `const [SizedBox(...)]` as `List<SizedBox>` and the `+`
    // against `_buildFilters()` (`List<Widget>`) crashes at runtime
    // with a subtype error.
    final List<Widget> header = widget.showHeader
        ? _buildFamilyHeader(context)
        : <Widget>[const SizedBox(height: 16)];
    final List<Widget> body = header +
        _buildFilters(context) +
        <Widget>[SizedBox(height: widget.bottomInset)];
    return ListView(
        primary: widget.primary,
        // topInset goes through ListView's own padding so the first
        // content sits below glass chrome but still scrolls under it.
        padding: EdgeInsets.only(top: widget.topInset),
        children: body
        //_buildFooter(context),
        );
  }

  List<Widget> _buildFamilyHeader(BuildContext context) {
    return [
      SizedBox(height: getTopPadding(context)),
      Column(
        children: [
          const SizedBox(height: 12),
          ProfileAvatar(
            template: profile.template,
            displayAlias: profile.displayAlias,
            size: 48,
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
          onSelect: (sel, option) =>
              _profiles.updateUserChoice(filter, sel, Markers.userTap),
          bgColor: color);
    } catch (e) {
      throw Exception(
          "Error getting filter decor, filter: ${filter.filterName}: $e");
    }
  }

}
