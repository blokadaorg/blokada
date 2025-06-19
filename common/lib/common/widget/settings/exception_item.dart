import 'package:common/common/widget/common_clickable.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/core/core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class ExceptionItem extends StatefulWidget {
  final String entry;
  final bool blocked;
  final Function(String) onRemove;
  final Function(String) onChange;

  const ExceptionItem({
    Key? key,
    required this.entry,
    required this.blocked,
    required this.onRemove,
    required this.onChange,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => ExceptionItemState();
}

class ExceptionItemState extends State<ExceptionItem> {
  @override
  Widget build(BuildContext context) {
    return _wrapInDismissible(context, widget.entry, widget.blocked, (ctx) => _buildItem(ctx));
  }

  Widget _buildItem(BuildContext context) {
    return CommonClickable(
      onTap: () {
        Slidable.of(context)?.openStartActionPane();
      },
      tapBorderRadius: BorderRadius.zero,
      bgColor: context.theme.bgColorCard,
      padding: const EdgeInsets.only(top: 12, bottom: 12, left: 0, right: 4),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Container(
            color: widget.blocked ? Colors.red : Colors.green,
            width: 4,
            height: 52,
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.entry,
                    style: const TextStyle(fontSize: 18), overflow: TextOverflow.ellipsis),
                Text(
                  "${widget.blocked ? "block" : "allow"}",
                  style: TextStyle(color: context.theme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(
            CupertinoIcons.chevron_forward,
            size: 16,
            color: context.theme.textSecondary,
          )
        ],
      ),
    );
  }

  Widget _wrapInDismissible(BuildContext context, String entry, bool blocked, WidgetBuilder child) {
    return Slidable(
      key: Key(entry),
      groupTag: '0',
      startActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.3,
        children: [
          SlidableAction(
            onPressed: (c) {
              widget.onChange(entry);
            },
            backgroundColor: context.theme.divider,
            foregroundColor: Colors.white,
            icon: CupertinoIcons.shield_lefthalf_fill,
            label: blocked ? "Allow" : "Block",
            //borderRadius: const BorderRadius.all(Radius.circular(8)),
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.3,
        children: [
          SlidableAction(
            onPressed: (c) {
              widget.onRemove(entry);
            },
            backgroundColor: Colors.red.withOpacity(0.95),
            foregroundColor: Colors.white,
            icon: CupertinoIcons.delete,
            label: "universal action delete".i18n,
            //borderRadius: const BorderRadius.all(Radius.circular(8)),
          ),
        ],
      ),
      child: Builder(builder: (context) {
        return child(context);
      }),
    );
  }
}
