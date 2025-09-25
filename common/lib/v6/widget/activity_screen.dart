import 'package:common/common/module/journal/journal.dart';
import 'package:common/common/navigation.dart';
import 'package:common/common/widget/common_clickable.dart';
import 'package:common/common/widget/settings/retention_section.dart';
import 'package:common/common/widget/stats/domain_detail_section.dart';
import 'package:common/common/widget/stats/stats_filter.dart';
import 'package:common/common/widget/stats/stats_section.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/common/widget/with_top_bar.dart';
import 'package:common/core/core.dart';
import 'package:common/platform/account/account.dart';
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
  late final _account = Core.get<AccountStore>();
  late final _journal = Core.get<JournalActor>();

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
        // Show only if retention is enabled
        // ... or if freemium since we show a sample data
        _showStats = retention == "24h" || _account.isFreemium;
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
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: _buildStatsScreenPhone(context),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsScreenPhone(BuildContext context) {
    if (_showStats) {
      return const StatsSection(deviceTag: null, isHeader: false);
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

  Widget _buildForTablet(BuildContext context) {
    return WithTopBar(
      title: "main tab activity".i18n,
      maxWidth: _showStats ? maxContentWidthTablet : maxContentWidth,
      topBarTrailing: _getStatsAction(context),
      child: _buildStatsScreenTablet(context),
    );
  }

  Widget _buildStatsScreenTablet(BuildContext context) {
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
        final entry = _arguments as UiJournalEntry;
        final mainEntry = _journal.getMainEntry(entry);
        return DomainDetailSection(
          entry: mainEntry,
          subdomainEntries: _journal.getSubdomainEntries(mainEntry),
        );
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
