import 'package:common/journal/channel.pg.dart';
import 'package:common/service/I18nService.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../journal/journal.dart';
import '../../stage/stage.dart';
import '../../stats/stats.dart';
import '../../util/di.dart';
import '../../util/trace.dart';
import '../theme.dart';
import '../touch.dart';

class Toplist extends StatelessWidget with TraceOrigin {
  final _store = dep<StatsStore>();
  final _stage = dep<StageStore>();
  final _journal = dep<JournalStore>();

  final UiStats stats;
  final bool blocked;

  Toplist({Key? key, required this.stats, required this.blocked})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<BlokadaTheme>()!;
    final toplist = stats.toplist.filter((e) => e.blocked == blocked);
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Column(
          children: (toplist.isNotEmpty)
              ? toplist.map((e) => _buildRow(context, e)).toList()
              : [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      "universal status waiting for data".i18n,
                      style: TextStyle(color: theme.textSecondary),
                    ),
                  ),
                ]),
    );
  }

  Widget _buildRow(BuildContext context, UiToplistEntry entry) {
    final theme = Theme.of(context).extension<BlokadaTheme>()!;
    return Touch(
      onLongTap: () => _copyEntry(entry.tld),
      decorationBuilder: (value) {
        return BoxDecoration(
          color: theme.bgColorHome3.withOpacity(value),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            if (entry.blocked)
              Container(
                width: 3,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            if (entry.blocked) const SizedBox(width: 6),
            Stack(
              alignment: Alignment.center,
              children: [
                Icon(CupertinoIcons.shield,
                    color: entry.blocked ? Colors.red : Colors.green, size: 52),
                Text(
                  (entry.value > 99) ? "99" : entry.value.toString(),
                  style: TextStyle(color: theme.textPrimary, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.tld ?? "toplist tld unknown".i18n,
                      style: const TextStyle(fontSize: 18)),
                  Text(
                    entry.company?.capitalize() ?? "toplist company other".i18n,
                    style: TextStyle(color: theme.textSecondary, fontSize: 12),
                  ),
                  Text(
                    _getAllowedBlockedText(entry),
                    style: TextStyle(color: theme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  _getAllowedBlockedText(UiToplistEntry entry) {
    var string = (entry.blocked)
        ? "activity state blocked".i18n
        : "activity state allowed".i18n;
    if (entry.value == 1) {
      return "$string ${"activity happened one time".i18n}";
    } else {
      return "$string ${"activity happened many times".i18n.replaceFirst("%s", entry.value.toString())}";
    }
  }

  _openActivityForEntry(String? entry) {
    traceAs("tappedStatsToplistItem", (trace) async {
      await _stage.setRoute(trace, StageTab.activity.name);
      await _journal.updateFilter(
        trace,
        deviceName: _store.selectedDevice,
        searchQuery: entry,
        showOnly: JournalFilterType.all,
      );
    });
  }

  _copyEntry(String? entry) {
    traceAs("tappedCopyEntry", (trace) async {
      if (entry == null) return;
      await Clipboard.setData(ClipboardData(text: entry));
    });
  }
}
