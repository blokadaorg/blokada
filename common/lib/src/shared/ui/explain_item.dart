import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/cupertino.dart';

class ExplainItemWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const ExplainItemWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: context.theme.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(description,
                    softWrap: true,
                    style: TextStyle(color: context.theme.textSecondary)),
              ],
            ),
          ),
        ],
      );
}
