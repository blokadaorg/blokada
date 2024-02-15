import 'package:common/common/widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class NavCloseButton extends StatefulWidget {
  final VoidCallback? onTap;

  const NavCloseButton({Key? key, this.onTap}) : super(key: key);

  @override
  State<StatefulWidget> createState() => NavCloseButtonState();
}

class NavCloseButtonState extends State<NavCloseButton> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap ?? () => Navigator.of(context).pop(),
      child: Container(
        decoration: BoxDecoration(
          color: context.theme.divider.withOpacity(0.05),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: Icon(
            size: 16,
            CupertinoIcons.xmark,
            color: context.theme.textSecondary,
          ),
        ),
      ),
    );
  }
}
