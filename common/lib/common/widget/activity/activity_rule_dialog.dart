import 'package:common/common/module/customlist/customlist.dart';
import 'package:common/common/module/journal/journal.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/core/core.dart';
import 'package:flutter/cupertino.dart';

enum ActivityRuleOption {
  automatic,
  allow,
  allowWithSubdomains,
}

class ActivityRuleDialog extends StatefulWidget {
  final String domainName;
  final UiJournalAction action;
  final CustomlistActor customlistActor;
  final Function(ActivityRuleOption)? onSelected;

  const ActivityRuleDialog({
    super.key,
    required this.domainName,
    required this.action,
    required this.customlistActor,
    this.onSelected,
  });

  @override
  State<ActivityRuleDialog> createState() => ActivityRuleDialogState();

  /// Get the currently selected option from the state
  static ActivityRuleOption? getSelectedOption(BuildContext context) {
    final state = context.findAncestorStateOfType<ActivityRuleDialogState>();
    return state?._selectedOption;
  }
}

class ActivityRuleDialogState extends State<ActivityRuleDialog> {
  late ActivityRuleOption _selectedOption;

  @override
  void initState() {
    super.initState();
    _selectedOption = _determineInitialOption();
  }

  ActivityRuleOption _determineInitialOption() {
    final domain = widget.domainName;

    // Check in both allowed and blocked lists
    // Priority: wildcard entries first, then exact matches

    // Check allowed list first
    if (widget.customlistActor.isInAllowedList(domain, wildcard: true)) {
      // Domain exists in allowed list with wildcard=true
      return ActivityRuleOption.allowWithSubdomains;
    } else if (widget.customlistActor.isInAllowedList(domain, wildcard: false)) {
      // Domain exists in allowed list with wildcard=false
      return ActivityRuleOption.allow;
    }

    // Check blocked list
    if (widget.customlistActor.isInBlockedList(domain, wildcard: true)) {
      // Domain exists in blocked list with wildcard=true
      return ActivityRuleOption.allowWithSubdomains;
    } else if (widget.customlistActor.isInBlockedList(domain, wildcard: false)) {
      // Domain exists in blocked list with wildcard=false
      return ActivityRuleOption.allow;
    }

    // Default to automatic if not in any list
    return ActivityRuleOption.automatic;
  }

  @override
  Widget build(BuildContext context) {
    // Determine action text based on customlist state or entry action
    final domain = widget.domainName;

    // Check if domain exists in customlists to determine the action verb
    String actionShortDomain;
    String actionDescDomain;
    String actionShortDomainAndSubdomains;
    String actionDescDomainAndSubdomains;

    if (widget.customlistActor.isInAllowedList(domain)) {
      // Domain is in allowed list, so the action is "allow"
      actionShortDomain = "dialog rule domain allow".i18n;
      actionDescDomain = "dialog rule domain desc allow".i18n.withParams(widget.domainName);
      actionShortDomainAndSubdomains = "dialog rule subdomains allow".i18n;
      actionDescDomainAndSubdomains =
          "dialog rule subdomains desc allow".i18n.withParams(widget.domainName);
    } else if (widget.customlistActor.isInBlockedList(domain)) {
      // Domain is in blocked list, so the action is "block"
      actionShortDomain = "dialog rule domain block".i18n;
      actionDescDomain = "dialog rule domain desc block".i18n.withParams(widget.domainName);
      actionShortDomainAndSubdomains = "dialog rule subdomains block".i18n;
      actionDescDomainAndSubdomains =
          "dialog rule subdomains desc block".i18n.withParams(widget.domainName);
    } else {
      // Domain not in customlists, use entry action
      // If domain was blocked, user wants to allow it
      // If domain was allowed, user wants to block it
      if (widget.action == UiJournalAction.block) {
        actionShortDomain = "dialog rule domain allow".i18n;
        actionDescDomain = "dialog rule domain desc allow".i18n.withParams(widget.domainName);
        actionShortDomainAndSubdomains = "dialog rule subdomains allow".i18n;
        actionDescDomainAndSubdomains =
            "dialog rule subdomains desc allow".i18n.withParams(widget.domainName);
      } else {
        actionShortDomain = "dialog rule domain block".i18n;
        actionDescDomain = "dialog rule domain desc block".i18n.withParams(widget.domainName);
        actionShortDomainAndSubdomains = "dialog rule subdomains block".i18n;
        actionDescDomainAndSubdomains =
            "dialog rule subdomains desc block".i18n.withParams(widget.domainName);
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildOption(
          ActivityRuleOption.automatic,
          "dialog rule auto".i18n,
          "dialog rule auto desc".i18n,
        ),
        const SizedBox(height: 16),
        _buildOption(
          ActivityRuleOption.allow,
          actionShortDomain,
          actionDescDomain,
        ),
        const SizedBox(height: 16),
        _buildOption(
          ActivityRuleOption.allowWithSubdomains,
          actionShortDomainAndSubdomains,
          actionDescDomainAndSubdomains,
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
