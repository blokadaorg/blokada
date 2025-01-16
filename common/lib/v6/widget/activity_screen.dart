import 'package:common/common/module/journal/journal.dart';
import 'package:common/common/navigation.dart';
import 'package:common/common/widget/common_clickable.dart';
import 'package:common/common/widget/settings/retention_section.dart';
import 'package:common/common/widget/stats/stats_detail_section.dart';
import 'package:common/common/widget/stats/stats_filter.dart';
import 'package:common/common/widget/stats/stats_section.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/common/widget/with_top_bar.dart';
import 'package:common/core/core.dart';
import 'package:common/platform/device/device.dart';
import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => ActivityScreenState();
}

class ActivityScreenState extends State<ActivityScreen> with Logging {
  final _device = Core.get<DeviceStore>();
  late final _filter = Core.get<JournalFilterValue>();

  var _showStats = false;

  Paths _path = Paths.activity;
  Object? _arguments;

  @override
  void initState() {
    super.initState();

    Navigation.openInTablet = (path, arguments) {
      if (!mounted) return;
      setState(() {
        _path = path;
        _arguments = arguments;
      });
    };

    autorun((_) {
      final retention = _device.retention;
      setState(() {
        _showStats = retention != "";
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = isTabletMode(context);

    if (isTablet) return _buildForTablet(context);
    return _buildForPhone(context);
  }

  Widget _buildForPhone(BuildContext context) {
    return WithTopBar(
      title: "main tab activity".i18n,
      topBarTrailing: _getStatsAction(context),
      child: const Row(
        children: [
          Expanded(
            flex: 1,
            child: StatsSection(deviceTag: null, isHeader: false),
          ),
        ],
      ),
    );
  }

  Widget _buildForTablet(BuildContext context) {
    return WithTopBar(
      title: "main tab activity".i18n,
      maxWidth: _showStats ? maxContentWidthTablet : maxContentWidth,
      topBarTrailing: _getStatsAction(context),
      child: _buildStatsScreen(context),
    );
  }

  Widget _buildStatsScreen(BuildContext context) {
    if (_showStats) {
      return Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          const Expanded(
            flex: 1,
            child: StatsSection(deviceTag: null, isHeader: false),
          ),
          Expanded(
            flex: 1,
            child: _buildForPath(_path, _arguments),
          ),
        ],
      );
    } else {
      return const Row(
        children: [
          Expanded(
            flex: 1,
            child: RetentionSection(),
          ),
        ],
      );
    }
  }

  Widget _buildForPath(Paths path, Object? arguments) {
    switch (path) {
      case Paths.deviceStatsDetail:
        return StatsDetailSection(entry: _arguments as UiJournalEntry);
      default:
        return Container();
    }
  }

  Widget? _getStatsAction(BuildContext context) {
    if (!_showStats) return null;

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
