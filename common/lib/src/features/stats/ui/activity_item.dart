import 'package:common/src/features/journal/domain/journal.dart';
import 'package:common/src/shared/automation/ids.dart';
import 'package:common/src/shared/layout/with_detail_pane.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:common/src/shared/ui/common_clickable.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/core/core.dart';
import 'package:flutter/cupertino.dart';

class ActivityItem extends StatefulWidget {
  /// Status shield size; small so the log reads as a list, not an alarm.
  static const double iconSize = 24;

  /// Height of a row at the default text size; loading placeholders match it.
  static const double rowHeight = 56;
  static const double rowPadding = 8;

  final UiJournalEntry entry;

  const ActivityItem({
    Key? key,
    required this.entry,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => ActivityItemState();
}

class ActivityItemState extends State<ActivityItem> {
  @override
  Widget build(BuildContext context) {
    // Highlight this row while its detail is open in the pane; selections
    // are journal entries, matched on the entry itself (domain + time).
    final selectionArguments = PaneSelection.of(context)?.arguments;
    final isSelected = selectionArguments is UiJournalEntry &&
        selectionArguments.domainName == widget.entry.domainName &&
        selectionArguments.timestamp == widget.entry.timestamp;

    final blocked = widget.entry.isBlocked();
    final status = blocked ? "stats label blocked".i18n : "stats label allowed".i18n;
    final subtitle = widget.entry.requests > 1
        ? "${widget.entry.timestampText} · ${_getActionString()}"
        : widget.entry.timestampText;

    // One spoken label in a fixed order: domain, blocked or allowed, time.
    return MergeSemantics(
      child: Semantics(
        identifier: AutomationIds.activityItem,
        button: true,
        label: "${widget.entry.domainName}\n$status\n$subtitle",
        child: Container(
          // Unified list-selection style: full-row square tint in the
          // shared accent-derived selection color.
          color: isSelected ? context.theme.selection : null,
          child: CommonClickable(
            onTap: () {
              Navigation.open(Paths.deviceStatsDetail, arguments: widget.entry);
            },
            tapBorderRadius: BorderRadius.zero,
            padding: const EdgeInsets.symmetric(vertical: ActivityItem.rowPadding),
            child: ExcludeSemantics(
              child: Opacity(
                opacity: widget.entry.modified ? 0.5 : 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: ActivityItem.rowHeight - 2 * ActivityItem.rowPadding,
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              middleEllipsis(widget.entry.domainName, maxLength: 32),
                              style: context.theme.text.body,
                              // One line each, so the row stays the placeholder's height.
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                            ),
                            Text(
                              subtitle,
                              style: context.theme.text.caption.copyWith(
                                color: context.theme.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Small, after the domain: the shield is a status, not the
                      // headline. The cross or check inside it keeps blocked and
                      // allowed apart without relying on colour.
                      Icon(
                        blocked
                            ? CupertinoIcons.xmark_shield_fill
                            : CupertinoIcons.checkmark_shield_fill,
                        color: blocked ? context.theme.blocked : context.theme.allowed,
                        size: ActivityItem.iconSize,
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        CupertinoIcons.right_chevron,
                        color: context.theme.textSecondary,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getActionString() {
    if (widget.entry.isBlocked()) {
      return "family activity blocked times".i18n.withParams(widget.entry.requests);
    } else {
      return "family activity allowed times".i18n.withParams(widget.entry.requests);
    }
  }
}
