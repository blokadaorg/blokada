import 'package:common/src/shared/automation/ids.dart';
import 'package:common/src/shared/ui/common_clickable.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/core/core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class ExceptionItem extends StatefulWidget {
  final String entry;
  final bool blocked;
  final bool wildcard;
  final Function(String) onRemove;
  final VoidCallback? onTap;

  const ExceptionItem({
    Key? key,
    required this.entry,
    required this.blocked,
    required this.wildcard,
    required this.onRemove,
    this.onTap,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => ExceptionItemState();
}

class ExceptionItemState extends State<ExceptionItem> {
  @override
  Widget build(BuildContext context) {
    return _wrapInDismissible(context, widget.entry, (ctx) => _buildItem(ctx));
  }

  Widget _buildItem(BuildContext context) {
    final displayEntry = widget.wildcard ? "*.${widget.entry}" : widget.entry;

    // MergeSemantics + a single Semantics node so the row exposes a stable id
    // to Appium (same proven pattern as SettingsItem); generic id is fine —
    // exploration just needs "tap a domain row" to reach the detail level.
    return MergeSemantics(
      child: Semantics(
        identifier: AutomationIds.exceptionItem,
        label: displayEntry,
        button: true,
        child: CommonClickable(
            onTap: widget.onTap ??
                () {
                  Slidable.of(context)?.openEndActionPane();
                },
            child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  middleEllipsis(displayEntry, maxLength: 32),
                  style: TextStyle(
                    fontSize: 16,
                    color: context.theme.textPrimary,
                  ),
                  overflow: TextOverflow.clip,
                ),
              ),
              Icon(
                CupertinoIcons.chevron_right,
                size: 16,
                color: context.theme.textSecondary,
              )
            ],
          ),
        ))));
  }

  Widget _wrapInDismissible(
      BuildContext context, String entry, WidgetBuilder child) {
    return Slidable(
      key: Key(entry),
      groupTag: '0',
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.3,
        children: [
          CustomSlidableAction(
            onPressed: (c) {
              widget.onRemove(entry);
            },
            backgroundColor: Colors.red.withOpacity(0.95),
            foregroundColor: Colors.white,
            // CustomSlidableAction (vs SlidableAction) so the delete control can
            // carry a stable automation id; the icon+label child mirrors the
            // previous look.
            child: MergeSemantics(
              child: Semantics(
                identifier: AutomationIds.exceptionDelete,
                label: "universal action delete".i18n,
                button: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(CupertinoIcons.delete, color: Colors.white),
                    const SizedBox(height: 4),
                    Text(
                      "universal action delete".i18n,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      child: Builder(builder: (context) {
        return child(context);
      }),
    );
  }
}
