import 'package:common/common/widget/common_card.dart';
import 'package:common/common/widget/theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ExpandableInfoCard extends StatefulWidget {
  final String text;
  final int maxChars;

  const ExpandableInfoCard({
    Key? key,
    required this.text,
    this.maxChars = 32,
  }) : super(key: key);

  @override
  State<ExpandableInfoCard> createState() => _ExpandableInfoCardState();
}

class _ExpandableInfoCardState extends State<ExpandableInfoCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final String displayText = _expanded
        ? widget.text
        : (widget.text.length > widget.maxChars
            ? "${widget.text.substring(0, widget.maxChars)}..."
            : widget.text);

    return GestureDetector(
      onTap: () {
        setState(() {
          _expanded = !_expanded;
        });
      },
      child: CommonCard(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                (!_expanded)
                    ? Icon(
                        CupertinoIcons.info,
                        color: context.theme.accent,
                        size: 20,
                      )
                    : Container(),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    displayText,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge!
                        .copyWith(color: context.theme.textSecondary),
                  ),
                ),
                (!_expanded && widget.text.length > widget.maxChars)
                    ? Icon(
                        CupertinoIcons.chevron_down,
                        size: 16,
                        color: context.theme.divider,
                      )
                    : Container(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
