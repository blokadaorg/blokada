import 'package:common/src/core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:provider/provider.dart';

/// Asks the user to approve sending the app log the agent requested. Shown
/// at the end of the chat as a card, not a bubble, since it needs a decision.
class SupportLogCard extends StatelessWidget {
  final VoidCallback onShare;
  final VoidCallback onCancel;
  final bool busy;

  const SupportLogCard({
    super.key,
    required this.onShare,
    required this.onCancel,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ChatTheme>().colors;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          border: Border.all(color: colors.onSurface.withOpacity(0.15)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description_outlined, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "support share log title".i18n,
                    style: text.titleMedium?.copyWith(color: colors.onSurface),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "support share log body".i18n,
              style: text.bodyMedium?.copyWith(color: colors.onSurface),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              children: [
                TextButton(
                  onPressed: busy ? null : onCancel,
                  child: Text("universal action cancel".i18n),
                ),
                FilledButton(
                  onPressed: busy ? null : onShare,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                  ),
                  child: Text("universal action share log".i18n),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The muted note left in the history once the log was shared or declined.
class SupportLogNote extends StatelessWidget {
  final bool shared;
  final DateTime when;

  const SupportLogNote({super.key, required this.shared, required this.when});

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ChatTheme>().colors;
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: colors.onSurface.withOpacity(0.6));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(shared ? Icons.check : Icons.block, size: 16, color: style?.color),
          const SizedBox(width: 4),
          Text(
            (shared ? "support share log done" : "support share log declined")
                .i18n,
            style: style,
          ),
          Text(" · ${context.watch<DateFormat>().format(when.toLocal())}", style: style),
        ],
      ),
    );
  }
}
