import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/cupertino.dart';

import 'package:common/src/shared/ui/common_clickable.dart';

/// A rounded, tappable row with a leading icon, a name and a trailing widget,
/// shared by the profile, filter and device pickers.
class ProfileButton extends StatefulWidget {
  final VoidCallback onTap;
  final String name;
  final IconData? icon;
  final Color? iconColor;
  final Widget? leading;
  final Widget? trailing;
  final EdgeInsets padding;
  final Color? borderColor;
  final Color? tapBgColor;

  /// Starts the name after [leading] instead of centring it across the row.
  /// The centred name runs under the leading badge once it is long, so lists
  /// of free-form names (such as device names) set this to keep it readable.
  final bool nameAfterLeading;

  const ProfileButton({
    super.key,
    required this.onTap,
    required this.name,
    this.icon,
    this.iconColor,
    this.leading,
    this.trailing,
    this.padding = const EdgeInsets.all(20),
    this.borderColor,
    this.tapBgColor,
    this.nameAfterLeading = false,
  });

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
          child: widget.nameAfterLeading
              ? Row(
                  children: [
                    _buildLeading(),
                    const SizedBox(width: 12),
                    Expanded(child: _buildName(TextAlign.start)),
                    _buildTrailing(),
                  ],
                )
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [_buildLeading(), _buildTrailing()],
                    ),
                    _buildName(TextAlign.center),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildLeading() =>
      widget.leading ?? Icon(widget.icon, color: widget.iconColor);

  Widget _buildTrailing() =>
      widget.trailing ??
      Icon(CupertinoIcons.chevron_right, color: context.theme.textSecondary);

  Widget _buildName(TextAlign align) => Text(
        widget.name,
        style: context.theme.text.body.semibold.copyWith(color: context.theme.textPrimary),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        textAlign: align,
      );
}
