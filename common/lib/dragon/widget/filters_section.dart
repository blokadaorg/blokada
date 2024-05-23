import 'dart:async';

import 'package:collection/collection.dart';
import 'package:common/common/defaults/filter_decor_defaults.dart';
import 'package:common/common/i18n.dart';
import 'package:common/common/model.dart';
import 'package:common/dragon/filter/selected_filters.dart';
import 'package:common/dragon/profile/controller.dart';
import 'package:common/dragon/widget/filter/filter.dart';
import 'package:common/dragon/widget/navigation.dart';
import 'package:common/dragon/widget/profile_utils.dart';
import 'package:common/util/di.dart';
import 'package:flutter/material.dart';

class FiltersSection extends StatefulWidget {
  final String profileId;
  final bool primary;

  const FiltersSection({Key? key, required this.profileId, this.primary = true})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => FiltersSectionState();
}

class FiltersSectionState extends State<FiltersSection> {
  late final _knownFilters = dep<KnownFilters>();
  late final _profiles = dep<ProfileController>();
  late final _selectedFilters = dep<SelectedFilters>();

  late JsonProfile profile;

  late StreamSubscription _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = _selectedFilters.onChange.listen((_) => setState(() {
          print("refreshing edit_profile: ${_selectedFilters.now}");
        }));
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    profile = _profiles.get(widget.profileId);

    return ListView(
        primary: widget.primary,
        children: <Widget>[
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
                      style: const TextStyle(
                          fontSize: 28, fontWeight: FontWeight.w700)),

                  // GestureDetector(
                  //   onTap: () {
                  //     showRenameDialog(context, "profile", widget.profile);
                  //   },
                  //   child: Text("Edit",
                  //       style: TextStyle(color: context.theme.family)),
                  // ),
                ],
              ),
              const SizedBox(height: 16),
            ] +
            _buildFilters(context) //+
        //_buildFooter(context),
        );
  }

  List<Widget> _buildFilters(BuildContext context) {
    final filters = <Widget>[];
    int i = 0;
    for (final filter in _knownFilters.get()) {
      final color = _cardColors.elementAtOrNull(i++);
      final selected = _selectedFilters.now
              .firstWhereOrNull((it) => it.filterName == filter.filterName)
              ?.options ??
          [];
      filters.add(_buildFilter(context, filter, selected, color: color));
    }
    return filters;
  }

  final List<Color?> _cardColors = [
    const Color(0xFFA9CCFE),
    null,
    const Color(0xFFF4B1C6),
    const Color(0XFFFDB39C),
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
          onSelect: (sel) => _profiles.updateUserChoice(filter, sel),
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
