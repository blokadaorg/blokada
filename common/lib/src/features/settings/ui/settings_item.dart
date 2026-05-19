import 'package:common/src/shared/ui/common_clickable.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/material.dart';

class SettingsItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final bool unread;

  /// Stable automation id for rows whose localized text is not enough for
  /// dynamic exploration to understand which setting was opened.
  final String? automationId;

  const SettingsItem(
      {super.key,
      required this.icon,
      required this.text,
      required this.onTap,
      this.unread = false,
      this.automationId});

  @override
  Widget build(BuildContext context) {
    final child = Stack(
      children: [
        CommonClickable(
          tapBorderRadius: BorderRadius.zero,
          onTap: onTap,
          child: Row(
            children: [
              Icon(icon, size: 22, color: context.theme.divider),
              const SizedBox(width: 10),
              Text(text, style: const TextStyle(fontSize: 14)),
              const Spacer(),
              Icon(Icons.chevron_right, size: 24, color: context.theme.divider),
            ],
          ),
        ),
        unread
            ? Padding(
                padding: const EdgeInsets.all(14.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: const SizedBox(
                        width: 18,
                        height: 18,
                        child: Center(
                          child: Text(
                            "1",
                            style: TextStyle(
                                color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : Container(),
      ],
    );

    final automationId = this.automationId;
    if (automationId == null) return child;

    // MergeSemantics collapses the inner clickable + Row(Icon, Text, chevron)
    // into one accessibility node so the identifier lands on the element
    // Appium can resolve (without it the id stays on a non-hittable container).
    return MergeSemantics(
      child: Semantics(
        identifier: automationId,
        label: text,
        button: true,
        child: child,
      ),
    );
  }
}
