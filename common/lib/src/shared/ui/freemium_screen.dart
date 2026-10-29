import 'dart:async';

import 'package:common/src/features/payment/domain/payment.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:common/src/shared/ui/minicard/minicard.dart';
import 'package:common/src/features/modal/ui/blur_background.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/core/core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// A blurred gate over a screen showing sample data, with one call to
/// action. By default it offers the upgrade for [placement]; [onAction]
/// replaces that with another action (turning activity logging on).
class FreemiumScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final Placement placement;

  /// Small label above the title, like "Sample".
  final String? badge;

  /// The call to action, instead of the upgrade.
  final String? actionLabel;
  final IconData? actionIcon;
  final Future<void> Function()? onAction;
  final String? actionSemanticsId;

  /// Below the call to action, like a link to the privacy policy.
  final Widget? footer;

  const FreemiumScreen({
    Key? key,
    required this.title,
    required this.subtitle,
    this.placement = Placement.primary,
    this.badge,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.actionSemanticsId,
    this.footer,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _FreemiumScreenState();
}

class _FreemiumScreenState extends State<FreemiumScreen>
    with TickerProviderStateMixin, Logging, Disposables {
  final _payment = Core.get<PaymentActor>();

  final GlobalKey<BlurBackgroundState> bgStateKey = GlobalKey();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    disposeAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          IgnorePointer(
            child: BlurBackground(
              key: bgStateKey,
              bgColor: Colors.black.withOpacity(0.2),
              blur: 4,
              canClose: () => false,
              child: Container(),
            ),
          ),
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: maxContentWidth),
              // Centered, and scrolls when large text makes the dialog taller
              // than the screen. Only the dialog takes touches, as before; the
              // space around it stays transparent to the screen below.
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  // The screen below owns the primary scroll controller.
                  primary: false,
                  hitTestBehavior: HitTestBehavior.deferToChild,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildCtaDialog(context),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.theme.accent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: context.theme.accent,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildCtaDialog(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 330),
        decoration: BoxDecoration(
          color: context.theme.bgColorCard.withOpacity(0.85),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (widget.badge != null) ...[
              _buildBadge(context, widget.badge!),
              const SizedBox(height: 12),
            ],
            Text(
              widget.title,
              style:
                  Theme.of(context).textTheme.headlineLarge!.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              widget.subtitle,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.start,
            ),
            const SizedBox(height: 32),
            MergeSemantics(
              child: Semantics(
                identifier: widget.actionSemanticsId,
                button: true,
                child: MiniCard(
                    onTap: () {
                      final onAction = widget.onAction;
                      if (onAction != null) {
                        unawaited(onAction());
                        return;
                      }
                      log(Markers.userTap).trace("tappedUpgrade", (m) async {
                        await _payment.openPaymentScreen(m, placement: widget.placement);
                      });
                    },
                    color: context.theme.accent,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 32),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            widget.actionIcon ?? CupertinoIcons.heart_fill,
                            color: context.theme.onAccent,
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              widget.actionLabel ?? "universal action upgrade short".i18n,
                              style: TextStyle(
                                  color: context.theme.onAccent,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    )),
              ),
            ),
            if (widget.footer != null) widget.footer!,
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }
}
