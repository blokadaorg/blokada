import 'dart:math' as math;

import 'package:common/src/features/support/domain/support.dart';
import 'package:common/src/shared/automation/ids.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:common/src/features/home/ui/header/header_button.dart';
import 'package:common/src/shared/ui/text_scale.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/app_variants/v6/widget/tab/tab_buttons.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'actions.dart';
import 'power_button.dart';

const pathHomeStats = "home/stats";

/// Home fits a 640 pt tall screen at the default text size.
const _homeFitsHeight = 640.0;

/// Whether Home uses its compact arrangement: larger than default text on a
/// screen too short for it (the 640 pt Home needs scaled by the text size).
/// Compact keeps the power button, the counter and the tab buttons within
/// about a screen at the accessibility sizes. The default text size always
/// keeps the regular arrangement.
bool isHomeCompact(BuildContext context, double height) {
  final scaler = MediaQuery.textScalerOf(context);
  return scaler.scale(1) > 1 && height < scaler.scale(_homeFitsHeight);
}

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
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = isHomeCompact(context, constraints.maxHeight);
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        compact ? _buildCompactHeader(context) : _buildHeader(context),
                        PowerButton(compact: compact),
                        Column(
                          children: [
                            HomeActions(compact: compact),
                            TabButtonsWidget(compact: compact),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsButton() => Semantics(
    identifier: AutomationIds.homeSettings,
    button: true,
    child: SmartHeaderButton(
      bgColor: Colors.transparent,
      unread: _unread.present ?? false,
      icon: CupertinoIcons.settings,
      onTap: () {
        Navigation.open(Paths.settings);
      },
    ),
  );

  Widget _buildLogo(BuildContext context) => Image.asset(
    "assets/images/header.png",
    width: 200,
    height: 28,
    fit: BoxFit.scaleDown,
    color: Theme.of(context).textTheme.bodyLarge!.color,
  );

  /// Settings on its own row, the logo under it.
  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 60, right: 16),
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [_buildSettingsButton()]),
        ),
        _buildLogo(context),
      ],
    );
  }

  /// Settings beside the logo, saving a row for the actions below, and only
  /// the status bar's height above them rather than the regular fixed 60.
  /// At the largest text sizes the logo goes too: it is decoration, and the
  /// room is worth more to the actions.
  Widget _buildCompactHeader(BuildContext context) {
    final top = math.max(MediaQuery.paddingOf(context).top, 20.0) + 8;
    if (isLargeTextScale(context)) {
      return Padding(
        padding: EdgeInsets.only(top: top, right: 16),
        child: Align(alignment: Alignment.centerRight, child: _buildSettingsButton()),
      );
    }
    return Padding(
      padding: EdgeInsets.only(top: top, right: 16, left: 16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          _buildLogo(context),
          Align(alignment: Alignment.centerRight, child: _buildSettingsButton()),
        ],
      ),
    );
  }
}
