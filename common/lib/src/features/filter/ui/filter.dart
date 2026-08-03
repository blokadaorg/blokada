import 'package:common/src/features/filter/domain/filter.dart';
import 'package:common/src/shared/ui/color.dart';
import 'package:common/src/features/filter/ui/filter_option.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/core/core.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';

class FilterWidget extends StatefulWidget {
  final Filter filter;
  final FilterDecor texts;
  final List<String> selections;
  final Function(List<String>, String) onSelect;
  final Color? bgColor;

  const FilterWidget({
    super.key,
    required this.filter,
    required this.texts,
    required this.selections,
    required this.onSelect,
    this.bgColor,
  });

  @override
  State<StatefulWidget> createState() => FilterWidgetState();
}

class FilterWidgetState extends State<FilterWidget> {
  @override
  Widget build(BuildContext context) {
    var bgColor1 = widget.bgColor;
    var bgColor2 = widget.bgColor?.lighten(12);
    var bgOptions = Colors.white38;
    if (context.theme.isDarkTheme()) {
      bgColor1 = bgColor1?.darken(36);
      bgColor2 = widget.bgColor?.darken(60);
      bgOptions = Colors.black38;
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 14,
                offset: const Offset(6, 6),
              ),
            ],
            gradient: LinearGradient(
              colors: [
                bgColor1 ?? context.theme.bgColorCard,
                bgColor2 ?? context.theme.bgColorCard,
              ],
              begin: Alignment.centerLeft,
              end: Alignment.bottomRight,
            )),
        child: Column(
          // Stretch so the header block spans the card even when its widest
          // line is short — the default centering floated cards with short,
          // non-wrapping descriptions and read as a stray left indent.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.texts.tags.map((e) => e.i18n).join(", ").toUpperCase(),
                      style: Theme.of(context).textTheme.titleSmall!.copyWith(
                            fontWeight: FontWeight.w500,
                            color: context.theme.divider,
                          )),
                  const SizedBox(height: 8.0),
                  Text(widget.texts.title.i18n,
                      style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                            fontWeight: FontWeight.bold,
                          )),
                  const SizedBox(height: 4.0),
                  Text(
                    widget.texts.description.i18n,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16.0),
            Container(
              decoration: BoxDecoration(
                color: (widget.bgColor == null) ? Colors.transparent : bgOptions,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Column(
                children: _buildFilterOptions(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFilterOptions(BuildContext context) {
    return widget.filter.options
        .map((it) {
          String? nameOverride;
          if (widget.filter.options.length == 1 || it.optionName == "primary") {
            nameOverride = widget.texts.title.i18n;
          }

          return <Widget>[
            FilterOptionWidget(
                option: it,
                nameOverride: nameOverride,
                colorOverride: widget.bgColor?.darken(20),
                selections: widget.selections,
                automationId: _filterOptionAutomationId(widget.filter, it),
                onSelect: (selected) {
                  _updateUserChoice(widget.filter, it.optionName, selected);
                }),
            Divider(
                indent: 16, endIndent: 16, thickness: 0.4, height: 4, color: context.theme.divider),
          ];
        })
        .flatten()
        .toList()
        .dropLast(1);
  }

  _updateUserChoice(Filter filter, String option, bool selected) {
    if (selected) {
      widget.selections.add(option);
    } else {
      widget.selections.remove(option);
    }
    widget.onSelect(widget.selections, option);
  }

  String _filterOptionAutomationId(Filter filter, Option option) {
    final filterName = _sanitizeAutomationSegment(filter.filterName);
    final optionName = _sanitizeAutomationSegment(option.optionName);
    return "automation.filter_option.$filterName.$optionName";
  }

  String _sanitizeAutomationSegment(String value) {
    final sanitized = value.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    return sanitized.isEmpty ? "unknown" : sanitized;
  }
}
