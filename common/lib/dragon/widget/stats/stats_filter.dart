import 'package:common/common/i18n.dart';
import 'package:common/common/model.dart';
import 'package:common/common/widget/common_item.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/dragon/journal/controller.dart';
import 'package:common/dragon/widget/profile_button.dart';
import 'package:common/util/di.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class StatsFilter extends StatefulWidget {
  final StatsFilterController ctrl;

  const StatsFilter({super.key, required this.ctrl});

  @override
  StatsFilterState createState() => StatsFilterState();
}

class StatsFilterState extends State<StatsFilter> {
  late JournalFilter filter;

  final TextEditingController _ctrl = TextEditingController(text: "");

  @override
  void initState() {
    super.initState();
    filter = widget.ctrl.filter;
    _ctrl.text = filter.searchQuery;
    _ctrl.addListener(() {
      filter = filter.updateOnly(searchQuery: _ctrl.text.toLowerCase());
      widget.ctrl.filter = filter;
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
                filter = filter.updateOnly(showOnly: JournalFilterType.all);
                widget.ctrl.filter = filter;
              });
            },
            icon: CupertinoIcons.shield,
            iconColor: filter.showOnly == JournalFilterType.all
                ? context.theme.textSecondary
                : context.theme.divider,
            name: "activity filter show all".i18n,
            borderColor: filter.showOnly == JournalFilterType.all
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
                filter = filter.updateOnly(showOnly: JournalFilterType.blocked);
                widget.ctrl.filter = filter;
              });
            },
            icon: CupertinoIcons.shield,
            iconColor: filter.showOnly == JournalFilterType.blocked
                ? Colors.red
                : context.theme.divider,
            name: "activity filter show blocked".i18n,
            borderColor: filter.showOnly == JournalFilterType.blocked
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
              filter = filter.updateOnly(showOnly: JournalFilterType.passed);
              widget.ctrl.filter = filter;
            });
          },
          icon: CupertinoIcons.shield,
          iconColor: filter.showOnly == JournalFilterType.passed
              ? Colors.green
              : context.theme.divider,
          name: "activity filter show allowed".i18n,
          borderColor: filter.showOnly == JournalFilterType.passed
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
                filter =
                    filter.updateOnly(sortNewestFirst: !filter.sortNewestFirst);
                widget.ctrl.filter = filter;
              });
            },
            icon: Icons.sort,
            text: "family stats filter most common".i18n,
            chevron: false,
            trailing: CupertinoSwitch(
              activeColor: context.theme.accent,
              value: !filter.sortNewestFirst,
              onChanged: (bool? value) {
                setState(() {
                  filter = filter.updateOnly(
                      sortNewestFirst: !filter.sortNewestFirst);
                  widget.ctrl.filter = filter;
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
  final _journal = dep<JournalController>();

  late JournalFilter filter;

  StatsFilterController() {
    filter = _journal.filter;
  }
}
