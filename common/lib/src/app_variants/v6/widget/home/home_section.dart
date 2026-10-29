import 'package:common/src/features/support/domain/support.dart';
import 'package:common/src/shared/automation/ids.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:common/src/features/home/ui/header/header_button.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/app_variants/v6/widget/tab/tab_buttons.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'actions.dart';
import 'power_button.dart';

const pathHomeStats = "home/stats";

class V6HomeSection extends StatefulWidget {
  V6HomeSection({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return V6HomeSectionState();
  }
}

class V6HomeSectionState extends State<V6HomeSection> with Logging, Disposables {
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
    final theme = Theme.of(context).extension<BlokadaTheme>()!;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.bgColorHome3,
            theme.bgColorHome2,
            theme.bgColorHome1,
            theme.bgColor,
            theme.bgColor,
          ],
        ),
      ),
      child: AbsorbPointer(
        absorbing: false,
        child: Stack(
          children: [
            // Fills the screen, with the room left split evenly above and
            // below the power button; scrolls instead when large text or a
            // short screen needs more room. spaceBetween rather than Spacers,
            // which can't flex in a scroll view.
            LayoutBuilder(builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        children: [
                          GestureDetector(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 60, right: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Semantics(
                                    identifier: AutomationIds.homeSettings,
                                    button: true,
                                    child: SmartHeaderButton(
                                        bgColor: Colors.transparent,
                                        unread: _unread.present ?? false,
                                        icon: CupertinoIcons.settings,
                                        onTap: () {
                                          Navigation.open(Paths.settings);
                                        }),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          GestureDetector(
                            child: Image.asset(
                              "assets/images/header.png",
                              width: 200,
                              height: 28,
                              fit: BoxFit.scaleDown,
                              color: Theme.of(context).textTheme.bodyLarge!.color,
                            ),
                          ),
                        ],
                      ),
                      PowerButton(),
                      const Column(
                        children: [
                          HomeActions(),
                          TabButtonsWidget(),
                          SizedBox(height: 24),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
