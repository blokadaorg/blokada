import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';

import '../../stats/stats.dart';
import '../theme.dart';

class Toplist extends StatelessWidget {
  final UiStats stats;

  Toplist({Key? key, required this.stats}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<BlokadaTheme>()!;
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Column(
          children: (stats.toplist.isNotEmpty)
              ? stats.toplist.map((e) => _buildRow(context, e)).toList()
              : [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      "Waiting for data",
                      style: TextStyle(color: theme.textSecondary),
                    ),
                  ),
                ]),
    );
  }

  Widget _buildRow(BuildContext context, UiToplistEntry entry) {
    final theme = Theme.of(context).extension<BlokadaTheme>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 28,
            decoration: BoxDecoration(
              color: entry.blocked ? Colors.red : Colors.green,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.tld ?? "unknown"),
                Text(
                  entry.company?.capitalize() ?? "Other",
                  style: TextStyle(color: theme.textSecondary, fontSize: 12),
                )
              ],
            ),
          ),
          Text(
            entry.value.toString(),
            style: TextStyle(color: theme.textSecondary),
          ),
        ],
      ),
    );
  }
}
