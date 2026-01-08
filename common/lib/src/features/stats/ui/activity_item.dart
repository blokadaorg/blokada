import 'package:common/src/features/journal/domain/journal.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:common/src/shared/ui/common_clickable.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/core/core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ActivityItem extends StatefulWidget {
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
    return CommonClickable(
      onTap: () {
        Navigation.open(Paths.deviceStatsDetail, arguments: widget.entry);
      },
      tapBorderRadius: BorderRadius.zero,
      padding: const EdgeInsets.only(top: 12, bottom: 12, left: 0, right: 8),
      child: Opacity(
        opacity: widget.entry.modified ? 0.5 : 1,
        child: Row(
          children: [
            const SizedBox(width: 12),
            Icon(
                widget.entry.isBlocked()
                    ? CupertinoIcons.xmark_shield_fill
                    : CupertinoIcons.checkmark_shield_fill,
                color: widget.entry.isBlocked() ? Colors.red : Colors.green,
                size: 52),
            const SizedBox(width: 6),
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(middleEllipsis(widget.entry.domainName),
                      style: const TextStyle(fontSize: 18), overflow: TextOverflow.clip),
                  Text(
                    widget.entry.timestampText,
                    style: TextStyle(color: context.theme.textSecondary, fontSize: 12),
                  ),
                  if (widget.entry.requests > 1)
                    Text(
                      _getActionString(),
                      style: TextStyle(color: context.theme.textSecondary, fontSize: 12),
                    ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.right_chevron,
              color: context.theme.textPrimary,
              size: 20,
            ),
            const SizedBox(width: 6),
          ],
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
