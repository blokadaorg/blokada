import 'package:common/src/core/core.dart';
import 'package:common/src/features/support/domain/support.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:provider/provider.dart';

/// What the card asks of the user for each client tool.
class _ToolCopy {
  final IconData icon;
  final String title;
  final String body;
  final String approve;

  const _ToolCopy(this.icon, this.title, this.body, this.approve);
}

const _copy = {
  SupportClientTool.attachLog: _ToolCopy(
    Icons.description_outlined,
    "support share log title",
    "support share log body",
    "universal action share log",
  ),
  SupportClientTool.dnsCheck: _ToolCopy(
    Icons.dns_outlined,
    "support network check title",
    "support network check body",
    "universal action run check",
  ),
};

/// Asks the user to approve what the agent requested of the app. Shown at
/// the end of the chat as a card, not a bubble, since it needs a decision.
class SupportActionCard extends StatelessWidget {
  final SupportClientTool tool;
  final VoidCallback onApprove;
  final VoidCallback onCancel;
  final bool busy;

  const SupportActionCard({
    super.key,
    required this.tool,
    required this.onApprove,
    required this.onCancel,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ChatTheme>().colors;
    final text = Theme.of(context).textTheme;
    final copy = _copy[tool]!;
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
                Icon(copy.icon, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    copy.title.i18n,
                    style: text.titleMedium?.copyWith(color: colors.onSurface),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(copy.body.i18n, style: text.bodyMedium?.copyWith(color: colors.onSurface)),
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
                  onPressed: busy ? null : onApprove,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                  ),
                  child: Text(copy.approve.i18n),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

const _noteKeys = {
  SupportNote.logShared: "support share log done",
  SupportNote.logDeclined: "support share log declined",
  SupportNote.dnsChecked: "support network check done",
  SupportNote.dnsDeclined: "support network check declined",
};

/// The muted note left in the history once a request was done or declined.
class SupportActionNote extends StatelessWidget {
  final SupportNote note;
  final DateTime when;

  const SupportActionNote({super.key, required this.note, required this.when});

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
          Icon(note.declined ? Icons.block : Icons.check, size: 16, color: style?.color),
          const SizedBox(width: 4),
          Text(_noteKeys[note]!.i18n, style: style),
          Text(" · ${context.watch<DateFormat>().format(when.toLocal())}", style: style),
        ],
      ),
    );
  }
}
