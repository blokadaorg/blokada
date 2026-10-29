import 'dart:io';
import 'dart:math';

import 'package:common/src/core/core.dart';
import 'package:common/src/features/support/domain/support.dart';
import 'package:common/src/features/support/ui/support_section.dart';
import 'package:common/src/shared/layout/window_shape.dart';
import 'package:common/src/shared/ui/nav_close_button.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/material.dart';

/// The support chat over the current screen, for entry points outside
/// Settings: a user who asks for help from the screen where something went
/// wrong keeps that screen in view, and is back on it after closing.
///
/// × is the only action. There is no way to end the chat, since closing is
/// enough and the session expires on its own.
class SupportSheet extends StatefulWidget {
  const SupportSheet({super.key});

  /// Share of the screen the sheet takes, leaving the screen behind visible.
  static const heightFactor = 0.6;

  @override
  State<StatefulWidget> createState() => SupportSheetState();
}

class SupportSheetState extends State<SupportSheet> {
  late final _unread = Core.get<SupportUnreadActor>();

  @override
  void initState() {
    super.initState();
    _unread.sheetOpened();
  }

  @override
  void dispose() {
    _unread.sheetClosed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // The sheet is not in a Scaffold that would make room for the keyboard,
    // so it lifts itself. On an Android phone the sheet already sits above
    // the navigation bar (see BottomManagerSheet), which the keyboard inset
    // also counts; the floating sheet on wide screens has no such padding.
    final aboveNavBar = Platform.isAndroid && media.size.width < minWidthFloatingSheet;
    final keyboard = max(
      0.0,
      media.viewInsets.bottom - (aboveNavBar ? media.viewPadding.bottom : 0.0),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final screen = media.size.height;
        // With the keyboard up on a small phone, 60% would not fit above it,
        // so the sheet takes what is left instead.
        final room = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : screen - media.viewPadding.top;
        final height = min(screen * SupportSheet.heightFactor, room - keyboard);

        // The sheet route brings no Material, which the composer's text
        // field and the default text style need.
        return Material(
          color: context.theme.bgColor,
          child: Padding(
            padding: EdgeInsets.only(bottom: keyboard),
            child: SizedBox(
              height: max(0.0, height),
              child: Column(
                children: [
                  _header(context),
                  Expanded(
                    // Where the sheet already keeps clear of the navigation
                    // bar, the composer must not add it again.
                    child: MediaQuery.removePadding(
                      context: context,
                      removeBottom: aboveNavBar,
                      child: const SupportSection(underTopBar: false),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            "support action chat".i18n,
            style: TextStyle(
              color: context.theme.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Positioned(right: 16, child: NavCloseButton()),
        ],
      ),
    );
  }
}
