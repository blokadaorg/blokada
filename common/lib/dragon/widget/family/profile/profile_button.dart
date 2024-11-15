import 'package:common/common/widget/theme.dart';
import 'package:flutter/cupertino.dart';

import '../../../../common/widget/common_clickable.dart';

class ProfileButton extends StatefulWidget {
  final VoidCallback onTap;
  final IconData icon;
  final Color iconColor;
  final String name;
  final Widget? trailing;
  final EdgeInsets padding;
  final Color? borderColor;
  final Color? tapBgColor;

  const ProfileButton({
    Key? key,
    required this.onTap,
    required this.icon,
    required this.iconColor,
    required this.name,
    this.trailing,
    this.padding = const EdgeInsets.all(20),
    this.borderColor,
    this.tapBgColor,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => ProfileButtonState();
}

class ProfileButtonState extends State<ProfileButton> {
  @override
  Widget build(BuildContext context) {
    return CommonClickable(
      onTap: widget.onTap,
      padding: EdgeInsets.zero,
      tapBgColor: widget.tapBgColor,
      child: Container(
        decoration: BoxDecoration(
          color: context.theme.divider.withOpacity(0.05),
          border: widget.borderColor == null
              ? null
              : Border.all(
                  color: widget.borderColor!,
                  width: 2.0,
                ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: widget.padding,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                widget.icon,
                color: widget.iconColor,
              ),
              Text(
                widget.name,
                style: TextStyle(
                  color: context.theme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                textAlign: TextAlign.center,
              ),
              widget.trailing ??
                  Icon(
                    CupertinoIcons.chevron_right,
                    color: context.theme.textSecondary,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
