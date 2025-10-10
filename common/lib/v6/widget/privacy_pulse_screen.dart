import 'package:common/common/module/journal/journal.dart';
import 'package:common/common/navigation.dart';
import 'package:common/common/widget/settings/retention_section.dart';
import 'package:common/common/widget/stats/domain_detail_section.dart';
import 'package:common/common/widget/stats/stats_detail_section.dart';
import 'package:common/common/widget/with_top_bar.dart';
import 'package:common/core/core.dart';
import 'package:common/platform/account/account.dart';
import 'package:common/platform/device/device.dart';
import 'package:common/v6/widget/home/stats/privacy_pulse_section.dart';
import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart';

class PrivacyPulseScreen extends StatefulWidget {
  const PrivacyPulseScreen({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => PrivacyPulseScreenState();
}

class PrivacyPulseScreenState extends State<PrivacyPulseScreen> with Logging {
  final _device = Core.get<DeviceStore>();
  late final _account = Core.get<AccountStore>();

  var _showStats = false;

  Paths _path = Paths.privacyPulse;
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
      title: "Privacy Pulse".i18n,
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
      return PrivacyPulseSection(
        autoRefresh: true,
        controller: ScrollController(),
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

  Widget _buildForTablet(BuildContext context) {
    return WithTopBar(
      title: "Privacy Pulse".i18n,
      maxWidth: _showStats ? maxContentWidthTablet : maxContentWidth,
      child: _buildStatsScreenTablet(context),
    );
  }

  Widget _buildStatsScreenTablet(BuildContext context) {
    if (_showStats) {
      return Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          Expanded(
            flex: 1,
            child: PrivacyPulseSection(
              autoRefresh: true,
              controller: ScrollController(),
            ),
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
        // Check if this is a Map argument (from toplist or subdomain navigation)
        if (_arguments is Map) {
          final args = _arguments as Map;
          final mainEntry = args['mainEntry'] as UiJournalMainEntry;
          final level = args['level'] as int? ?? 2;  // Default to level 2
          final domain = args['domain'] as String? ?? mainEntry.domainName;

          return DomainDetailSection(
            entry: mainEntry,
            level: level,
            domain: domain,
          );
        }
        // Normal entry from journal - use StatsDetailSection
        final entry = _arguments as UiJournalEntry;
        return StatsDetailSection(entry: entry, primary: false);
      default:
        return Container();
    }
  }
}
