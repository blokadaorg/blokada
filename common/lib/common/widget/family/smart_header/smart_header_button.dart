import 'package:common/common/widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SmartHeaderButton extends StatefulWidget {
  final VoidCallback? onTap;
  final IconData? icon;
  final Widget? iconWidget;

  const SmartHeaderButton({super.key, this.onTap, this.icon, this.iconWidget});

  @override
  State<StatefulWidget> createState() => SmartHeaderButtonState();
}

class SmartHeaderButtonState extends State<SmartHeaderButton> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.theme.textPrimary.withOpacity(0.15),
        // color: widget.icon == CupertinoIcons.settings
        //     ? Colors.transparent
        //     : context.theme.textPrimary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(24),
      ),
      child: SizedBox(
        width: 48,
        height: 48,
        child: widget.iconWidget != null
            ? widget.iconWidget
            : Touch(
                onTap: widget.onTap,
                decorationBuilder: (value) {
                  return BoxDecoration(
                    color: context.theme.bgMiniCard.withOpacity(value * 0.25),
                    borderRadius: BorderRadius.circular(24),
                  );
                },
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Icon(
                    widget.icon,
                    color: Colors.white,
                  ),
                ),
              ),
      ),
    );
  }
}
