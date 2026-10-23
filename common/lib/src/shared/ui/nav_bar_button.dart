import 'package:common/src/core/core.dart';
import 'package:common/src/shared/ui/common_clickable.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Whether the bars draw the iOS 26 look: bar buttons in superellipse
/// bubbles and a back chevron without the previous screen's name.
///
/// Read from the theme rather than `dart:io` so widget tests can render the
/// iOS branch. Android keeps the older look until its own style is decided.
bool useIosBarStyle(BuildContext context) => Theme.of(context).platform == TargetPlatform.iOS;

/// Height of a bar button bubble, the same for text and the back chevron so
/// both sides of a bar line up. 44 is Apple's minimum tap target.
const double navBarButtonHeight = 44;

const _bubbleShape = RoundedSuperellipseBorder(
  borderRadius: BorderRadius.all(Radius.circular(navBarButtonHeight / 2)),
);

/// A tint of the text colour rather than a surface colour, so the bubble
/// shows on every bar: page-coloured, card-coloured and blurred alike.
Color _bubbleColor(BuildContext context) => context.theme.textPrimary.withOpacity(0.08);

/// A tappable action in a top bar (Search, Add, Save, Done...).
///
/// Exists so every bar action takes the platform's bar-button look from one
/// place: on iOS a superellipse bubble, as iOS 26 draws them; elsewhere the
/// plain [CommonClickable] the bars used before. [selected] tints the
/// action, e.g. Search while a filter is applied.
class NavBarButton extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;
  final bool selected;

  /// Padding on platforms without the bubble; defaults to [CommonClickable]'s.
  final EdgeInsets? padding;

  const NavBarButton({
    super.key,
    required this.onTap,
    required this.child,
    this.selected = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    if (!useIosBarStyle(context)) {
      return CommonClickable(
        onTap: onTap,
        bgColor: selected ? context.theme.selection : null,
        padding: padding,
        child: child,
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: navBarButtonHeight),
      child: CommonClickable(
        onTap: onTap,
        shape: _bubbleShape,
        bgColor: selected ? context.theme.selection : _bubbleColor(context),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        // The minimum height stretches the box past a short label, which
        // would otherwise sit at its top instead of the bubble's middle.
        child: Center(widthFactor: 1, heightFactor: 1, child: child),
      ),
    );
  }
}

/// The iOS 26 back button: a bare chevron in a round bubble.
///
/// The bar no longer prints where back goes, so the destination moves into
/// the semantics value: VoiceOver reads "Back, `destination`, button", the
/// same as the label used to say on screen.
class NavBarBackButton extends StatelessWidget {
  final VoidCallback? onTap;

  /// Title of the screen back returns to, for screen readers only.
  final String? destination;

  /// Stable automation id, so tests can find the button without its label.
  final String? identifier;

  const NavBarBackButton({
    super.key,
    required this.onTap,
    this.destination,
    this.identifier,
  });

  @override
  Widget build(BuildContext context) {
    // MergeSemantics folds the decorative icon into one button node, so the
    // identifier and label reach the accessibility tree.
    return MergeSemantics(
      child: Semantics(
        identifier: identifier,
        label: 'universal action back'.i18n,
        value: destination,
        button: true,
        child: CommonClickable(
          onTap: onTap,
          shape: _bubbleShape,
          bgColor: _bubbleColor(context),
          padding: EdgeInsets.zero,
          child: SizedBox.square(
            dimension: navBarButtonHeight,
            child: Icon(CupertinoIcons.chevron_back, color: context.theme.link, size: 22),
          ),
        ),
      ),
    );
  }
}
