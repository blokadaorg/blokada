import 'package:common/src/features/support/domain/support.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:common/src/features/home/ui/header/header_button.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/app_variants/family/module/family/family.dart';
import 'package:flutter/cupertino.dart';

class SmartHeader extends StatefulWidget {
  final FamilyPhase phase;

  const SmartHeader({super.key, required this.phase});

  @override
  State<StatefulWidget> createState() => Header();
}

class Header extends State<SmartHeader>
    with TickerProviderStateMixin, Logging, Disposables {
  late final _unread = Core.get<SupportUnread>();

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
      list.add(SmartHeaderButton(
          unread: _unread.present ?? false,
          icon: CupertinoIcons.person_crop_circle,
          onTap: () {
            Navigation.open(Paths.settings);
          }));
      list.add(const SizedBox(width: 4));
    }

    return list;
  }
}
