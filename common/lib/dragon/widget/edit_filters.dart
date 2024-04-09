import 'dart:async';

import 'package:collection/collection.dart';
import 'package:common/common/defaults/filter_decor_defaults.dart';
import 'package:common/common/model.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/dragon/filter/selected_filters.dart';
import 'package:common/dragon/profile/controller.dart';
import 'package:common/dragon/widget/filter/filter.dart';
import 'package:common/dragon/widget/home/top_bar.dart';
import 'package:common/dragon/widget/profile_utils.dart';
import 'package:common/util/di.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class EditFiltersSheet extends StatefulWidget {
  final String profileId;

  const EditFiltersSheet({Key? key, required this.profileId}) : super(key: key);

  @override
  State<StatefulWidget> createState() => EditFiltersSheetState();
}

class EditFiltersSheetState extends State<EditFiltersSheet> {
  late final _knownFilters = dep<KnownFilters>();
  late final _profiles = dep<ProfileController>();
  late final _selectedFilters = dep<SelectedFilters>();

  late JsonProfile profile;

  final ScrollController _scrollController = ScrollController();

  late StreamSubscription _subscription;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateTopBar);
    _subscription = _selectedFilters.onChange.listen((_) => setState(() {
          print("refreshing edit_profile: ${_selectedFilters.now}");
        }));
  }

  void _updateTopBar() {
    Provider.of<TopBarController>(context, listen: false)
        .updateScrollPos(_scrollController.offset);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateTopBar);
    _scrollController.dispose();
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    profile = _profiles.get(widget.profileId);

    return Scaffold(
      backgroundColor: context.theme.bgColor,
      body: Stack(
        children: [
          ListView(
            controller: _scrollController,
            padding: EdgeInsets.zero,
            children: <Widget>[
                  const SizedBox(height: 100),
                  const SizedBox(height: 16),
                  Column(
                    children: [
                      const SizedBox(height: 12),
                      Icon(
                        getProfileIcon(profile.template),
                        size: 48,
                        color: getProfileColor(profile.template),
                      ),
                      const SizedBox(height: 8),
                      Text("${profile.displayAlias} Profile",
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
                _buildFilters(context) +
                _buildFooter(context),
          ),
          TopBar(title: "Blocklists"),
        ],
      ),
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
          onSelect: (sel) => _updateUserChoice(filter, sel),
          bgColor: color);
    } catch (e) {
      throw Exception(
          "Error getting filter decor, filter: ${filter.filterName}: $e");
    }
  }

  _updateUserChoice(Filter filter, List<String> selections) {
    final selected = _selectedFilters.now;
    final index =
        selected.indexWhere((it) => it.filterName == filter.filterName);
    if (index == -1) {
      selected.add(FilterSelection(filter.filterName, selections));
    } else {
      selected[index] = FilterSelection(filter.filterName, selections);
    }
    _profiles.updateUserChoice(selected);
  }

  List<Widget> _buildFooter(BuildContext context) {
    return [
      const SizedBox(height: 16),
      Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: const Padding(
          padding: EdgeInsets.all(18.0),
          child: Text("Delete this profile",
              style: TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.w500)),
        ),
      ),
      const SizedBox(height: 48),
    ];
  }
}
