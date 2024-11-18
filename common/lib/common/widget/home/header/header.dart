import 'package:common/common/model/model.dart';
import 'package:common/common/widget/home/header/header_button.dart';
import 'package:common/core/core.dart';
import 'package:common/dragon/navigation.dart';
import 'package:common/dragon/support/support_unread.dart';
import 'package:flutter/cupertino.dart';

class SmartHeader extends StatefulWidget {
  final FamilyPhase phase;

  const SmartHeader({super.key, required this.phase});

  @override
  State<StatefulWidget> createState() => Header();
}

class Header extends State<SmartHeader>
    with TickerProviderStateMixin, Logging, Disposables {
  late final _unread = DI.get<SupportUnread>();

  @override
  void initState() {
    super.initState();
    disposeLater(_unread.onChange.listen(rebuild));
  }

  @override
  void dispose() {
    disposeAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _buildButtons(context),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildButtons(BuildContext context) {
    final list = <Widget>[];

    list.add(const Spacer());

    if (!widget.phase.isLocked2() &&
        widget.phase != FamilyPhase.linkedExpired) {
      list.add(SmartHeaderButton.HeaderButton(
          unread: (_unread.resolved) ? _unread.now : false,
          icon: CupertinoIcons.person_crop_circle,
          onTap: () {
            Navigation.open(Paths.settings);
          }));
      list.add(const SizedBox(width: 4));
    }

    return list;
  }
}
