import 'dart:math' as math;

import 'package:common/src/features/funnel/domain/funnel.dart';
import 'package:common/src/features/notification/domain/notification.dart';
import 'package:common/src/shared/automation/ids.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:common/src/shared/ui/minicard/minicard.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'package:common/src/app_variants/v6/widget/tab/tab_item.dart';
import 'package:flutter/cupertino.dart';
import 'package:mobx/mobx.dart' as mobx;

/// The Privacy Pulse and Blocklists buttons under Home's actions.
class TabButtonsWidget extends StatefulWidget {
  /// Home's compact arrangement at large text sizes: the buttons stack as
  /// full-width rows with the icon beside the title, which would otherwise
  /// wrap (or break mid-word) in half the screen width.
  final bool compact;

  const TabButtonsWidget({Key? key, this.compact = false}) : super(key: key);

  @override
  State<TabButtonsWidget> createState() => _TabState();
}

class _TabState extends State<TabButtonsWidget> with Disposables, Logging {
  final _stage = Core.get<StageStore>();
  final _weeklyReport = Core.get<WeeklyReportActor>();
  final List<mobx.ReactionDisposer> _disposers = [];
  bool _hasUnseenReport = false;

  @override
  void initState() {
    super.initState();
    _disposers.add(
      mobx.autorun((_) {
        final hasUnseen = _weeklyReport.hasUnseen.value;
        if (!mounted) return;
        if (hasUnseen != _hasUnseenReport) {
          setState(() {
            _hasUnseenReport = hasUnseen;
          });
        }
      }),
    );
  }

  @override
  void dispose() {
    for (final disposer in _disposers) {
      disposer();
    }
    super.dispose();
  }

  _tap(StageTab tab) async {
    if (tab == StageTab.activity) {
      funnelSignal(Markers.userTap, FunnelEvent.pulseOpenedHome);
      Navigation.open(Paths.privacyPulse);
      _updateStage(StageTab.activity);
    } else if (tab == StageTab.advanced) {
      Navigation.open(Paths.advanced);
      _updateStage(StageTab.advanced);
    }
  }

  _updateStage(StageTab tab) async {
    await sleepAsync(const Duration(milliseconds: 600));
    _stage.setRoute(tab.name, Markers.userTap);
  }

  @override
  Widget build(BuildContext context) {
    final compact = widget.compact;
    final buttons = [
      _wrapInDecor(
        context,
        TabItem(
          icon: CupertinoIcons.checkmark_shield,
          title: "privacy pulse section header".i18n,
          active: false,
          showUnreadBadge: _hasUnseenReport,
          horizontal: compact,
        ),
        onTap: () => _tap(StageTab.activity),
        automationId: AutomationIds.homePrivacyPulse,
        label: "privacy pulse section header".i18n,
      ),
      _wrapInDecor(
        context,
        TabItem(
          icon: CupertinoIcons.cube_box,
          title: "advanced section header packs".i18n,
          active: false,
          horizontal: compact,
        ),
        onTap: () => _tap(StageTab.advanced),
        automationId: AutomationIds.homeAdvanced,
        label: "advanced section header packs".i18n,
      ),
    ];
    if (compact) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: buttons),
      );
    }
    return Row(mainAxisSize: MainAxisSize.min, children: buttons);
  }

  Widget _wrapInDecor(
    BuildContext context,
    Widget child, {
    required VoidCallback onTap,
    required String automationId,
    required String label,
  }) {
    final card = Semantics(
      identifier: automationId,
      label: label,
      button: true,
      child: MiniCard(onTap: onTap, child: child),
    );
    if (widget.compact) {
      // As wide as Home's compact actions above.
      final width = math.min(MediaQuery.sizeOf(context).width - 32, 420).toDouble();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: SizedBox(width: width, child: card),
      );
    }
    // Wider with large text, up to an equal share of the row.
    final width = MediaQuery.textScalerOf(context).scale(114);
    return Flexible(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16),
        child: Semantics(
          identifier: automationId,
          label: label,
          button: true,
          child: MiniCard(
            onTap: onTap,
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    );
  }
}
