import 'package:common/common/module/journal/journal.dart';
import 'package:common/common/navigation.dart';
import 'package:common/common/widget/common_clickable.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/common/widget/two_letter_icon.dart';
import 'package:common/core/core.dart';
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
            widget.entry.isBlocked()
                ? Container(
                    color: Colors.red,
                    width: 4,
                    height: 52,
                  )
                : Container(width: 4),
            Stack(
              alignment: Alignment.center,
              children: [
                Icon(CupertinoIcons.shield,
                    color: widget.entry.isBlocked() ? Colors.red : Colors.green, size: 52),
                Transform.translate(
                  offset: const Offset(0, -3),
                  child: Text(
                    (widget.entry.requests > 99) ? "99" : widget.entry.requests.toString(),
                    style: TextStyle(color: context.theme.textPrimary, fontSize: 12),
                  ),
                ),
              ],
            ),
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
                  Text(
                    _getActionString(),
                    style: TextStyle(color: context.theme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            (Core.act.isFamily) ? Container() : TwoLetterIconWidget(name: widget.entry.deviceName),
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
