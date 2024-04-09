import 'package:flutter/cupertino.dart';

import 'touch.dart';
import 'theme.dart';

class BackEditHeaderWidget extends StatelessWidget {
  final String name;
  final VoidCallback? onBack;
  final VoidCallback? onEdit;

  const BackEditHeaderWidget({
    Key? key,
    required this.name,
    this.onBack,
    this.onEdit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 8),
        Touch(
          onTap: onBack,
          decorationBuilder: (value) {
            return BoxDecoration(
              color: context.theme.bgMiniCard.withOpacity(value),
              borderRadius: BorderRadius.circular(4),
            );
          },
          child: Padding(
            padding:
                const EdgeInsets.only(left: 2, right: 8, top: 8, bottom: 8),
            child: Row(
              children: [
                Icon(CupertinoIcons.chevron_left,
                    color: context.theme.textSecondary, size: 18),
                Text(name),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
