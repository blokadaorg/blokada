import 'dart:ui' as ui;

import 'package:common/src/core/core.dart';
import 'package:common/src/shared/ui/common_clickable.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// iOS-style top navigation bar: back chevron with the previous screen's
/// title on the leading edge, centered current-screen [title] in the
/// middle, optional [trailing] action on the right.
///
/// Used as `Scaffold.appBar` via `PreferredSizeWidget`. Built as an
/// explicit 1/2/1 [Row] rather than a Material [AppBar] because that
/// path produces clipped trailing actions when a custom `leadingWidth`
/// and `centerTitle: true` are combined.
///
/// Falls back to the universal "Back" label when [previousPageTitle] is
/// null, so a caller that doesn't know the previous screen's name still
/// gets a sensible back-row instead of a bare chevron.
class BackTitleNavBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String? previousPageTitle;
  final Widget title;
  final Widget? trailing;
  final VoidCallback? onBackTap;
  final Key? backKey;
  /// Bar fill colour shown beneath the blur. Defaults to the page's
  /// `bgColor`; callers whose Scaffold body is a different surface
  /// (e.g. ProfileEditorPage on `bgColorCard`) should pass that surface
  /// instead so the bar reads as a translucent layer of the host page,
  /// not a coloured ribbon on top of it.
  final Color? backgroundColor;

  const BackTitleNavBar({
    super.key,
    this.previousPageTitle,
    required this.title,
    this.trailing,
    this.onBackTap,
    this.backKey,
    this.backgroundColor,
  });

  static const double _height = kToolbarHeight;

  @override
  Size get preferredSize => const Size.fromHeight(_height);

  @override
  Widget build(BuildContext context) {
    final backText = previousPageTitle ?? 'universal action back'.i18n;
    // Glass effect: a BackdropFilter under a translucent fill so body
    // content (when Scaffold has `extendBodyBehindAppBar: true`) blurs
    // through as it scrolls under the bar. ClipRect bounds the blur to
    // the bar's rectangle — otherwise BackdropFilter samples and blurs
    // the entire screen below it. Material wraps the whole thing so
    // ink-style interactions inside (the back row's CommonClickable
    // press highlight) keep working.
    final fill = (backgroundColor ?? context.theme.bgColor).withOpacity(0.78);
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Material(
          color: fill,
          elevation: 0,
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: _height,
              child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Leading region: 25% of bar width, content aligned left.
              // Flex layout (vs Stack + Positioned) keeps the centered
              // title clear of leading + trailing content even when one
              // side is wider, the way Apple's UINavigationBar does.
              Flexible(
                flex: 1,
                fit: FlexFit.tight,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: CommonClickable(
                    key: backKey,
                    onTap:
                        onBackTap ?? () => Navigator.of(context).maybePop(),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.chevron_back,
                            color: context.theme.accent, size: 22),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(backText,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: TextStyle(
                                  color: context.theme.accent,
                                  fontSize: 17)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Centered title region: 50%. Wrapping in Center positions
              // any natural-sized child (Text, Row, etc.) at the visual
              // centre of the available 50% slice — which, with balanced
              // 1/2/1 flex, is the centre of the whole bar.
              Flexible(
                flex: 2,
                fit: FlexFit.tight,
                child: Center(child: title),
              ),
              // Trailing region: 25%, content aligned right. Empty
              // SizedBox keeps the flex slot balanced when no trailing
              // action is provided so the centered title stays centered.
              Flexible(
                flex: 1,
                fit: FlexFit.tight,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: trailing ?? const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
      ),
    );
  }
}
