import 'package:common/common/dialog.dart';
import 'package:common/common/module/journal/journal.dart';
import 'package:common/common/widget/common_item.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/core/core.dart';
import 'package:common/family/widget/profile/profile_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class StatsFilter extends StatefulWidget {
  final StatsFilterController filter;

  const StatsFilter({super.key, required this.filter});

  @override
  StatsFilterState createState() => StatsFilterState();
}

class StatsFilterState extends State<StatsFilter> {
  final TextEditingController _ctrl = TextEditingController(text: "");

  @override
  void initState() {
    super.initState();
    _ctrl.text = widget.filter.draft.searchQuery;
    _ctrl.addListener(() {
      widget.filter.draft =
          widget.filter.draft.updateOnly(searchQuery: _ctrl.text.toLowerCase());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12.0),
          child: Material(
            child: TextField(
              controller: _ctrl,
              decoration: InputDecoration(
                filled: true,
                fillColor: context.theme.bgColor,
                focusColor: context.theme.bgColor,
                hoverColor: context.theme.bgColor,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                enabledBorder: OutlineInputBorder(
                  borderSide:
                      BorderSide(color: context.theme.bgColor, width: 0.0),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide:
                      BorderSide(color: context.theme.bgColor, width: 0.0),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: ProfileButton(
            onTap: () {
              setState(() {
                widget.filter.draft = widget.filter.draft
                    .updateOnly(showOnly: JournalFilterType.all);
              });
            },
            icon: CupertinoIcons.shield,
            iconColor: widget.filter.draft.showOnly == JournalFilterType.all
                ? context.theme.textSecondary
                : context.theme.divider,
            name: "activity filter show all".i18n,
            borderColor: widget.filter.draft.showOnly == JournalFilterType.all
                ? context.theme.divider.withOpacity(0.20)
                : null,
            tapBgColor: context.theme.divider.withOpacity(0.1),
            padding: const EdgeInsets.only(left: 12),
            trailing: const SizedBox(height: 48),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: ProfileButton(
            onTap: () {
              setState(() {
                widget.filter.draft = widget.filter.draft
                    .updateOnly(showOnly: JournalFilterType.blocked);
              });
            },
            icon: CupertinoIcons.shield,
            iconColor: widget.filter.draft.showOnly == JournalFilterType.blocked
                ? Colors.red
                : context.theme.divider,
            name: "activity filter show blocked".i18n,
            borderColor:
                widget.filter.draft.showOnly == JournalFilterType.blocked
                    ? Colors.red.withOpacity(0.30)
                    : null,
            tapBgColor: context.theme.divider.withOpacity(0.1),
            padding: const EdgeInsets.only(left: 12),
            trailing: const SizedBox(height: 48),
          ),
        ),
        ProfileButton(
          onTap: () {
            setState(() {
              widget.filter.draft = widget.filter.draft
                  .updateOnly(showOnly: JournalFilterType.passed);
            });
          },
          icon: CupertinoIcons.shield,
          iconColor: widget.filter.draft.showOnly == JournalFilterType.passed
              ? Colors.green
              : context.theme.divider,
          name: "activity filter show allowed".i18n,
          borderColor: widget.filter.draft.showOnly == JournalFilterType.passed
              ? Colors.green.withOpacity(0.30)
              : null,
          tapBgColor: context.theme.divider.withOpacity(0.1),
          padding: const EdgeInsets.only(left: 12),
          trailing: const SizedBox(height: 48),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: context.theme.divider.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: CommonItem(
            onTap: () {
              setState(() {
                widget.filter.draft = widget.filter.draft.updateOnly(
                    sortNewestFirst: !widget.filter.draft.sortNewestFirst);
              });
            },
            icon: Icons.sort,
            text: "family stats filter most common".i18n,
            chevron: false,
            trailing: CupertinoSwitch(
              activeColor: context.theme.accent,
              value: !widget.filter.draft.sortNewestFirst,
              onChanged: (bool? value) {
                setState(() {
                  widget.filter.draft = widget.filter.draft.updateOnly(
                      sortNewestFirst: !widget.filter.draft.sortNewestFirst);
                });
              },
            ),
          ),
        ),
      ],
    );
  }
}

class StatsFilterController {
  late final _filter = Core.get<JournalFilterValue>();

  late JournalFilter draft;

  StatsFilterController() {
    draft = _filter.now;
  }
}

void showStatsFilterDialog(
  BuildContext context, {
  required Function(JournalFilter) onConfirm,
}) {
  final ctrl = StatsFilterController();

  showDefaultDialog(
    context,
    title: Text("universal action search".i18n),
    content: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        StatsFilter(filter: ctrl),
      ],
    ),
    actions: (context) => [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text("universal action cancel".i18n),
      ),
      TextButton(
        onPressed: () {
          Navigator.of(context).pop();
          onConfirm(ctrl.draft);
        },
        child: Text("universal action save".i18n),
      ),
    ],
  );
}
