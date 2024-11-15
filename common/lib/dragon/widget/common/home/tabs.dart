import 'dart:ui';

import 'package:common/common/widget/theme.dart';
import 'package:flutter/cupertino.dart';

class Tabs extends StatefulWidget {
  final bool enabled;
  final int tab;
  final void Function(int) onTab;

  const Tabs({
    super.key,
    required this.enabled,
    required this.tab,
    required this.onTab,
  });

  @override
  State<StatefulWidget> createState() => TabsState();
}

class TabsState extends State<Tabs> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 94,
      child: Stack(
        children: [
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 25,
                sigmaY: 25,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: context.theme.panelBackground.withOpacity(0.2),
                  border: Border(
                    top: BorderSide(
                      width: 1,
                      color: context.theme.divider.withOpacity(0.05),
                    ),
                  ),
                ),
                height: 104,
                //color: context.theme.divider.withOpacity(0.05),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 24, right: 24, top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _buildTabs(context),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTabs(BuildContext context) {
    return <Widget>[
      _buildTab(context, widget.tab == 0, 0, CupertinoIcons.home, "Home"),
      SizedBox(width: 32),
      _buildTab(context, widget.tab == 1, 1,
          CupertinoIcons.list_bullet_below_rectangle, "Blocking"),
      SizedBox(width: 32),
      _buildTab(context, widget.tab == 2, 2, CupertinoIcons.person_crop_circle,
          "Account"),
    ];
  }

  Widget _buildTab(BuildContext context, bool active, int index, IconData icon,
      String label) {
    final color = active ? context.theme.accent : context.theme.textPrimary;
    return GestureDetector(
      onTap: () {
        if (widget.enabled) widget.onTab(index);
      },
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SizedBox(
          height: 48,
          child: Column(
            children: [
              Icon(
                icon,
                color: color,
              ),
              Text(label, style: TextStyle(color: color))
            ],
          ),
        ),
      ),
    );
  }
}
