import 'package:common/common/module/payment/payment.dart';
import 'package:common/common/navigation.dart';
import 'package:common/common/widget/freemium_screen.dart';
import 'package:common/common/widget/minicard/minicard.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/core/core.dart';
import 'package:common/family/module/stats/stats.dart';
import 'package:common/platform/account/account.dart';
import 'package:common/platform/stats/stats.dart';
import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart' as mobx;

import '../../../../common/widget/stats/privacy_pulse.dart';
import '../../../../common/widget/stats/recent_activity.dart';
import '../../../../common/widget/stats/top_domains.dart';
import '../../../../common/widget/stats/totalcounter.dart';

class PrivacyPulseSection extends StatefulWidget {
  final bool autoRefresh;
  final ScrollController controller;

  const PrivacyPulseSection({
    Key? key,
    required this.autoRefresh,
    required this.controller,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => PrivacyPulseSectionState();
}

class PrivacyPulseSectionState extends State<PrivacyPulseSection> with Logging {
  final _store = Core.get<StatsStore>();
  late final _accountStore = Core.get<AccountStore>();

  var stats = UiStats.empty();

  bool get _isFreemium {
    return _accountStore.isFreemium;
  }

  @override
  void initState() {
    super.initState();
    if (widget.autoRefresh) {
      mobx.autorun((_) {
        setState(() {
          stats = _store.stats;
        });
      });
    }

    // Fetch toplists once when screen loads
    _fetchToplists();
  }

  void _fetchToplists() {
    log(Markers.userTap).trace("privacyPulseFetchToplists", (m) async {
      await _store.fetchToplists(m);
    });
  }

  @override
  Widget build(BuildContext context) {
    return content();
  }

  Widget content() {
    final theme = Theme.of(context).extension<BlokadaTheme>()!;
    return Stack(
      children: [
        IgnorePointer(
          ignoring: _isFreemium,
          child: Container(
            decoration: BoxDecoration(
              color: theme.bgColor,
            ),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: maxContentWidth),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: ListView(
                    controller: widget.controller,
                    children: [
                      SizedBox(height: getTopPadding(context)),
                      MiniCard(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: PrivacyPulse(stats: stats),
                        ),
                      ),
                      const SizedBox(height: 12),
                      RecentActivity(),
                      const SizedBox(height: 12),
                      TopDomains(),
                      const SizedBox(height: 48),
                      TotalCounter(stats: stats),
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        (_isFreemium)
            ? FreemiumScreen(
                title: "freemium activity cta header".i18n,
                subtitle: "freemium activity cta desc".i18n,
                placement: Placement.freemiumStats,
              )
            : Container(),
      ],
    );
  }
}