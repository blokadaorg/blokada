import 'package:common/common/widget/theme.dart';
import 'package:flutter/cupertino.dart';

enum ActivityRuleOption {
  automatic,
  allow,
  allowWithSubdomains,
}

class ActivityRuleDialog extends StatefulWidget {
  final String domainName;
  final Function(ActivityRuleOption)? onSelected;

  const ActivityRuleDialog({
    super.key,
    required this.domainName,
    this.onSelected,
  });

  @override
  State<ActivityRuleDialog> createState() => ActivityRuleDialogState();
}

class ActivityRuleDialogState extends State<ActivityRuleDialog> {
  ActivityRuleOption _selectedOption = ActivityRuleOption.automatic;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildOption(
          ActivityRuleOption.automatic,
          "Use automatic protection",
          "Block or allow this domain based on your selected filters.\n(Default setting)",
        ),
        const SizedBox(height: 16),
        _buildOption(
          ActivityRuleOption.allow,
          "Always allow this domain",
          "Ignore filters and let traffic through to ${widget.domainName}.",
        ),
        const SizedBox(height: 16),
        _buildOption(
          ActivityRuleOption.allowWithSubdomains,
          "Always allow this domain and subdomains",
          "Let traffic through to ${widget.domainName} and all addresses under it.",
        ),
      ],
    );
  }

  Widget _buildOption(ActivityRuleOption option, String title, String description) {
    final isSelected = _selectedOption == option;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedOption = option;
        });
        if (widget.onSelected != null) {
          widget.onSelected!(option);
        }
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            child: Icon(
              isSelected ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
              color: isSelected ? context.theme.accent : context.theme.textSecondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.theme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.theme.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
