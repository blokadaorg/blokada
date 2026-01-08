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

    return CommonClickable(
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
        ));
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
