import 'dart:async';

import 'package:common/common/module/filter/filter.dart';
import 'package:common/common/module/journal/journal.dart';
import 'package:common/common/navigation.dart';
import 'package:common/common/widget/common_clickable.dart';
import 'package:common/common/widget/stats/stats_detail_section.dart';
import 'package:common/common/widget/stats/stats_filter.dart';
import 'package:common/common/widget/stats/stats_section.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/common/widget/with_top_bar.dart';
import 'package:common/core/core.dart';
import 'package:common/family/module/device_v3/device.dart';
import 'package:common/family/module/family/family.dart';
import 'package:common/family/widget/device/device_section.dart';
import 'package:common/family/widget/filters_section.dart';
import 'package:flutter/material.dart';

class DeviceScreen extends StatefulWidget {
  final DeviceTag tag;

  const DeviceScreen({Key? key, required this.tag}) : super(key: key);

  @override
  State<DeviceScreen> createState() => DeviceScreenState();
}

class DeviceScreenState extends State<DeviceScreen> {
  late final _family = Core.get<FamilyDevicesValue>();
  late final _filter = Core.get<JournalFilterValue>();
  late final _selectedFilters = Core.get<SelectedFilters>();

  Paths _path = Paths.deviceStats;
  Object? _arguments;

  late StreamSubscription _subscription;
  bool built = false;

  @override
  void initState() {
    super.initState();
    _subscription = _selectedFilters.onChange.listen((_) => rebuild());
    Navigation.openInTablet = (path, arguments) {
      if (!mounted) return;
      setState(() {
        _path = path;
        _arguments = arguments;
      });
    };
  }

  rebuild() {
    if (!mounted) return;
    if (!built) return;
    setState(() {});
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    built = true;
    final device = _family.now.getDevice(widget.tag);
    final isTablet = isTabletMode(context);

    if (isTablet) return _buildForTablet(context, device);
    return _buildForPhone(context, device);
  }

  Widget _buildForPhone(BuildContext context, FamilyDevice device) {
    return WithTopBar(
      title: device.displayName,
      child: DeviceSection(tag: widget.tag),
    );
  }

  Widget _buildForTablet(BuildContext context, FamilyDevice device) {
    return WithTopBar(
      title: device.displayName,
      topBarTrailing: _getStatsAction(context),
      maxWidth: maxContentWidthTablet,
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: DeviceSection(tag: widget.tag),
          ),
          Expanded(
            flex: 1,
            child: _buildForPath(_path, device, _arguments),
          ),
        ],
      ),
    );
  }

  Widget _buildForPath(Paths path, FamilyDevice device, Object? arguments) {
    switch (path) {
      case Paths.deviceStats:
        return StatsSection(
            deviceTag: widget.tag, primary: false, isHeader: false);
      case Paths.deviceStatsDetail:
        final entry = arguments as UiJournalEntry;
        return StatsDetailSection(entry: entry, primary: false);
      case Paths.deviceFilters:
        return FamilyFiltersSection(
          profileId: device.profile.profileId,
          primary: false,
        );
      default:
        return Container();
    }
  }

  Widget? _getStatsAction(BuildContext context) {
    if (_path != Paths.deviceStats) return null;

    return CommonClickable(
        onTap: () {
          showStatsFilterDialog(context, onConfirm: (filter) {
            _filter.now = filter;
          });
        },
        child: Text(
          "universal action search".i18n,
          style: TextStyle(
            color: context.theme.accent,
            fontSize: 17,
          ),
        ));
  }
}
