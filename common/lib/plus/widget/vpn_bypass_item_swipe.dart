import 'package:common/core/core.dart';
import 'package:common/plus/module/bypass/bypass.dart';
import 'package:common/plus/widget/vpn_bypass_item.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class AppBypassItemSwipe extends StatelessWidget {
  final InstalledApp app;
  final Widget? icon;
  final VoidCallback onRemove;

  const AppBypassItemSwipe({
    Key? key,
    required this.app,
    required this.icon,
    required this.onRemove,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _wrapInDismissible(
      context,
      app.packageName,
      (context) => AppBypassItem(
        app: app,
        icon: icon,
        onTap: () {
          Slidable.of(context)?.openEndActionPane();
        },
      ),
    );
  }

  Widget _wrapInDismissible(
      BuildContext context, String packageName, WidgetBuilder child) {
    return Slidable(
      key: Key(packageName),
      groupTag: '0',
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.3,
        children: [
          SlidableAction(
            onPressed: (c) => onRemove(),
            backgroundColor: Colors.red.withOpacity(0.95),
            foregroundColor: Colors.white,
            icon: CupertinoIcons.delete,
            label: "universal action delete".i18n,
            borderRadius: const BorderRadius.all(Radius.circular(8)),
          ),
        ],
      ),
      child: Builder(builder: (context) {
        return child(context);
      }),
    );
  }
}
