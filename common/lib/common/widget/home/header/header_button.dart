import 'package:common/common/widget/theme.dart';
import 'package:common/common/widget/touch.dart';
import 'package:flutter/material.dart';

class SmartHeaderButton extends StatefulWidget {
  final VoidCallback? onTap;
  final IconData? icon;
  final Widget? iconWidget;
  final bool unread;
  final Color? bgColor;

  const SmartHeaderButton(
      {super.key,
      this.onTap,
      this.icon,
      this.iconWidget,
      this.unread = false,
      this.bgColor});

  @override
  State<StatefulWidget> createState() => SmartHeaderButtonState();
}

class SmartHeaderButtonState extends State<SmartHeaderButton> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topRight,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 6.0, top: 6.0),
          child: Container(
            decoration: BoxDecoration(
              color:
                  widget.bgColor ?? context.theme.textPrimary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SizedBox(
              width: 48,
              height: 48,
              child: widget.iconWidget ??
                  Touch(
                    onTap: widget.onTap,
                    decorationBuilder: (value) {
                      return BoxDecoration(
                        color:
                            context.theme.bgMiniCard.withOpacity(value * 0.25),
                        borderRadius: BorderRadius.circular(12),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(
                        widget.icon,
                        color: widget.bgColor == null
                            ? Colors.white
                            : context.theme.textPrimary,
                      ),
                    ),
                  ),
            ),
          ),
        ),
        widget.unread
            ? Container(
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
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    )),
              )
            : Container(),
      ],
    );
  }
}
