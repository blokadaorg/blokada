import 'package:common/src/features/notification/domain/notification.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:common/src/shared/ui/minicard/minicard.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'package:common/src/app_variants/v6/widget/tab/tab_item.dart';
import 'package:flutter/cupertino.dart';
import 'package:mobx/mobx.dart' as mobx;

class TabButtonsWidget extends StatefulWidget {
  const TabButtonsWidget({Key? key}) : super(key: key);

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
    _disposers.add(mobx.autorun((_) {
      final hasUnseen = _weeklyReport.hasUnseen.value;
      if (!mounted) return;
      if (hasUnseen != _hasUnseenReport) {
        setState(() {
          _hasUnseenReport = hasUnseen;
        });
      }
    }));
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _wrapInDecor(
          context,
          TabItem(
            icon: CupertinoIcons.checkmark_shield,
            title: "privacy pulse section header".i18n,
            active: false,
            showUnreadBadge: _hasUnseenReport,
          ),
          onTap: () => _tap(StageTab.activity),
        ),
        _wrapInDecor(
          context,
          TabItem(
            icon: CupertinoIcons.cube_box,
            title: "main tab advanced".i18n,
            active: false,
          ),
          onTap: () => _tap(StageTab.advanced),
        ),
      ],
    );
  }

  Widget _wrapInDecor(BuildContext context, Widget child, {required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16),
      child: MiniCard(onTap: onTap, child: SizedBox(width: 114, child: child)),
    );
  }
}
