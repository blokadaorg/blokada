import 'package:common/common/navigation.dart';
import 'package:common/common/widget/minicard/minicard.dart';
import 'package:common/core/core.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:common/v6/widget/tab/tab_item.dart';
import 'package:flutter/cupertino.dart';

class TabButtonsWidget extends StatefulWidget {
  const TabButtonsWidget({Key? key}) : super(key: key);

  @override
  State<TabButtonsWidget> createState() => _TabState();
}

class _TabState extends State<TabButtonsWidget> with Disposables {
  final _stage = Core.get<StageStore>();

  _tap(StageTab tab) async {
    if (tab == StageTab.activity) {
      Navigation.open(Paths.activity);
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
            icon: CupertinoIcons.chart_bar,
            title: "main tab activity".i18n,
            active: false,
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

  Widget _wrapInDecor(BuildContext context, Widget child,
      {required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16),
      child: MiniCard(onTap: onTap, child: SizedBox(width: 114, child: child)),
    );
  }
}
