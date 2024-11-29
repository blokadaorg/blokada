import 'package:common/common/navigation.dart';
import 'package:common/common/widget/common_divider.dart';
import 'package:common/common/widget/stats/activity_item.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/core/core.dart';
import 'package:common/family/module/customlist_v3/customlist.dart';
import 'package:common/family/module/device_v3/device.dart';
import 'package:common/family/module/journal/journal.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';

class StatsSection extends StatefulWidget {
  final DeviceTag deviceTag;
  final bool primary;

  const StatsSection({Key? key, required this.deviceTag, this.primary = true})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => StatsSectionState();
}

class StatsSectionState extends State<StatsSection> {
  late final _journal = DI.get<JournalActor>();
  late final _custom = DI.get<CustomlistActor>();

  bool _isReady = false;
  late List<UiJournalEntry> _entries;

  @override
  void initState() {
    super.initState();
    _journal.onChange = () {
      if (!mounted) return;
      setState(() {
        _isReady = true;
        _entries = _journal.filteredEntries;
      });
    };
    _custom.onChange = () {
      _reload();
    };
    _reload();
  }

  _reload() async {
    if (!mounted) return;
    await _journal.fetch(widget.deviceTag, Markers.stats);
    setState(() {
      _isReady = true;
      _entries = _journal.filteredEntries;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ListView(
        primary: widget.primary,
        children: [
              SizedBox(height: getTopPadding(context)),
              Container(
                decoration: BoxDecoration(
                  color: context.theme.bgMiniCard,
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12)),
                ),
                height: 12,
              ),
            ] +
            (!_isReady || _entries.isEmpty
                ? _buildEmpty(context)
                : _buildItems(context)) +
            [
              Container(
                decoration: BoxDecoration(
                  color: context.theme.bgMiniCard,
                  borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12)),
                ),
                height: 12,
              ),
            ],
      ),
    );
  }

  List<Widget> _buildItems(BuildContext context) {
    return _entries.mapIndexed((index, it) {
      return Container(
        color: context.theme.bgMiniCard,
        child: Column(children: [
          ActivityItem(entry: it),
          index < _entries.length - 1
              ? const CommonDivider(indent: 60)
              : Container(),
        ]),
      );
    }).toList();
  }

  List<Widget> _buildEmpty(BuildContext context) {
    return [
      Container(
        color: context.theme.bgMiniCard,
        child: Center(
          child: Text(
            (!_isReady || _journal.allEntries.isEmpty)
                ? "universal status waiting for data".i18n
                : "family search empty".i18n,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ];
  }
}
