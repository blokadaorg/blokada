import 'package:common/src/app_variants/v6/widget/home/stats/privacy_pulse_section.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/features/settings/ui/retention_section.dart';
import 'package:common/src/features/stats/ui/top_domains.dart';
import 'package:common/src/features/payment/domain/payment.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/shared/ui/freemium_screen.dart';
import 'package:common/src/platform/device/device.dart';
import 'package:common/src/shared/automation/ids.dart';
import 'package:common/src/shared/layout/window_shape.dart';
import 'package:common/src/shared/layout/with_detail_pane.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:common/src/shared/ui/with_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart';

/// v6 Privacy Pulse (toplists/charts). With retention enabled (or
/// freemium sample data) the pulse is the master pane and tapped domains
/// render alongside it on expanded windows; without retention it renders
/// the retention opt-in alone.
class PrivacyPulseScreen extends StatefulWidget {
  final ToplistRange? initialToplistRange;

  const PrivacyPulseScreen({
    Key? key,
    this.initialToplistRange,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => PrivacyPulseScreenState();
}

class PrivacyPulseScreenState extends State<PrivacyPulseScreen> with Logging {
  final _device = Core.get<DeviceStore>();
  late final _account = Core.get<AccountStore>();

  var _showStats = false;
  var _isFreemium = false;

  late final ReactionDisposer _autorunDisposer;

  @override
  void initState() {
    super.initState();

    _autorunDisposer = autorun((_) {
      final retention = _device.retention;
      setState(() {
        // Show only if retention is enabled
        // ... or if freemium since we show a sample data
        _isFreemium = _account.isFreemium;
        _showStats = retention == "24h" || _isFreemium;
      });
    });
  }

  @override
  void dispose() {
    _autorunDisposer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_showStats) {
      return Semantics(
        identifier: AutomationIds.screenPrivacyPulse,
        child: WithTopBar(
          title: "privacy pulse section header".i18n,
          child: const RetentionSection(),
        ),
      );
    }

    return WithDetailPane(
      title: "privacy pulse section header".i18n,
      screenSemanticsId: AutomationIds.screenPrivacyPulse,
      master: PrivacyPulseSection(
        autoRefresh: true,
        controller: ScrollController(),
        initialRange: widget.initialToplistRange,
      ),
      detailPaths: const {Paths.deviceStatsDetail},
      // The pulse sections spread into two columns while solo, so give the
      // master the whole box; it narrows (and the section collapses back to
      // one column) when a domain detail splits the screen.
      soloMaxWidth: maxContentWidthTwoPane,
      overlay: _isFreemium
          ? FreemiumScreen(
              title: "freemium activity cta header".i18n,
              subtitle: "freemium activity cta desc".i18n,
              placement: Placement.freemiumStats,
            )
          : null,
    );
  }
}
