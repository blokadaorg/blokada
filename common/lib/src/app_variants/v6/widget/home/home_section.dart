import 'package:common/src/features/support/domain/support.dart';
import 'package:common/src/shared/automation/ids.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:common/src/features/home/ui/header/header_button.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/app_variants/v6/widget/tab/tab_buttons.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:relative_scale/relative_scale.dart';

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
            RelativeBuilder(builder: (context, height, width, sy, sx) {
              return Column(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
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
                  const Spacer(),
                  const Spacer(),
                  PowerButton(),
                  const Spacer(),
                  const Spacer(),
                  const HomeActions(),
                  const TabButtonsWidget(),
                  const SizedBox(height: 24),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}
