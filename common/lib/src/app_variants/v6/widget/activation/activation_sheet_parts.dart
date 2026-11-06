import 'package:common/src/shared/ui/minicard/minicard.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/material.dart';

/// Shared layout of the activation sheets (#457), matching the Private DNS
/// sheet they sit next to: content scrolls, buttons stay at the bottom, and
/// in a short window (split screen, large text) everything scrolls together.
class ActivationSheetLayout extends StatelessWidget {
  final List<Widget> body;
  final List<Widget> footer;

  const ActivationSheetLayout({super.key, required this.body, required this.footer});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final content = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: body),
        );
        final bottom = [const SizedBox(height: 16), ...footer, const SizedBox(height: 8)];
        final short = constraints.maxHeight < MediaQuery.textScalerOf(context).scale(480);
        if (short) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [content, ...bottom],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: SingleChildScrollView(child: content)),
            ...bottom,
          ],
        );
      },
    );
  }
}

/// A sheet title, scaled down rather than wrapped on narrow phones.
class ActivationHeader extends StatelessWidget {
  final String text;

  const ActivationHeader(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 16),
      child: Semantics(
        header: true,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displaySmall!.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class ActivationSecondary extends StatelessWidget {
  final String text;
  final bool center;

  const ActivationSecondary(this.text, {super.key, this.center = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      softWrap: true,
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: TextStyle(color: context.theme.textSecondary),
    );
  }
}

/// The accent button of a sheet. A null [onTap] shows it dimmed while a
/// save is running.
class ActivationPrimaryButton extends StatelessWidget {
  final String label;
  final String automationId;
  final VoidCallback? onTap;

  const ActivationPrimaryButton({
    super.key,
    required this.label,
    required this.automationId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: MergeSemantics(
        child: Semantics(
          identifier: automationId,
          button: true,
          enabled: onTap != null,
          child: Opacity(
            opacity: onTap == null ? 0.5 : 1,
            child: MiniCard(
              onTap: onTap,
              color: context.theme.accent,
              child: SizedBox(
                height: 32,
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(color: context.theme.onAccent, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The quiet second choice under a primary button, like "Not now".
class ActivationSecondaryButton extends StatelessWidget {
  final String label;
  final String automationId;
  final VoidCallback? onTap;

  const ActivationSecondaryButton({
    super.key,
    required this.label,
    required this.automationId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: MergeSemantics(
        child: Semantics(
          identifier: automationId,
          button: true,
          enabled: onTap != null,
          child: TextButton(
            onPressed: onTap,
            child: Text(
              label,
              style: context.theme.text.callout.semibold.copyWith(color: context.theme.accent),
            ),
          ),
        ),
      ),
    );
  }
}
