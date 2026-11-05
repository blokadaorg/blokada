import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/material.dart';

class DeviceCardHeader extends StatelessWidget {
  final String text;
  final String iconName;
  final Color color;
  final IconData? chevronIcon;
  final String? chevronText;

  const DeviceCardHeader({
    super.key,
    required this.text,
    required this.iconName,
    required this.color,
    this.chevronIcon,
    this.chevronText,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              // TwoLetterIconWidget(name: iconName),
              // const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: context.theme.text.body.semibold.copyWith(color: color),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
        if (chevronIcon != null)
          Row(
            children: [
              if (chevronText != null)
                Text(chevronText!,
                    style: TextStyle(color: context.theme.textSecondary)),
              Icon(chevronIcon, color: context.theme.textSecondary),
            ],
          )
      ],
    );
  }
}
