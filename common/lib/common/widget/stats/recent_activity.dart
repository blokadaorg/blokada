import 'package:common/common/module/journal/journal.dart';
import 'package:common/common/navigation.dart';
import 'package:common/common/widget/common_card.dart';
import 'package:common/common/widget/common_clickable.dart';
import 'package:common/common/widget/common_divider.dart';
import 'package:common/common/widget/domain_name_text.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/core/core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class RecentActivity extends StatefulWidget {
  const RecentActivity({super.key});

  @override
  State<StatefulWidget> createState() => RecentActivityState();
}

enum ActivityTab { blocked, allowed }

class RecentActivityState extends State<RecentActivity> with Disposables {
  ActivityTab _selectedTab = ActivityTab.blocked;
  late final _journal = Core.get<JournalActor>();
  late final _journalEntries = Core.get<JournalEntriesValue>();

  List<UiJournalEntry> get _blockedEntries {
    final entries = _journalEntries.now;
    return entries.where((entry) => entry.isBlocked()).take(12).toList();
  }

  List<UiJournalEntry> get _allowedEntries {
    final entries = _journalEntries.now;
    return entries.where((entry) => !entry.isBlocked()).take(12).toList();
  }

  @override
  void initState() {
    super.initState();
    // Listen to journal entries changes and rebuild
    disposeLater(_journalEntries.onChange.listen((it) {
      if (mounted) {
        setState(() {});
      }
    }));
    // Fetch journal entries
    _journal.fetch(Markers.stats, tag: null);
  }

  @override
  void dispose() {
    disposeAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentEntries = _selectedTab == ActivityTab.blocked ? _blockedEntries : _allowedEntries;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title header with Show All link
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Recent Activity",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: context.theme.textPrimary,
                    ),
                  ),
                  CommonClickable(
                    onTap: () {
                      Navigation.open(Paths.activity);
                    },
                    child: Text(
                      "Show All",
                      style: TextStyle(
                        fontSize: 16,
                        color: context.theme.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Combined card with segmented control and list
            CommonCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  // Segmented control inside card
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: CupertinoSlidingSegmentedControl<ActivityTab>(
                        groupValue: _selectedTab,
                        onValueChanged: (ActivityTab? value) {
                          if (value != null) {
                            setState(() => _selectedTab = value);
                          }
                        },
                        children: {
                          ActivityTab.blocked: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            child: Text(
                              "Blocked",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          ActivityTab.allowed: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            child: Text(
                              "Allowed",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        },
                      ),
                    ),
                  ),

                  const CommonDivider(),

                  // Activity list or empty state
                  if (currentEntries.isEmpty)
                    _buildEmptyState()
                  else
                    for (int i = 0; i < currentEntries.length; i++) ...{
                      _buildActivityItem(currentEntries[i]),
                      if (i < currentEntries.length - 1) const CommonDivider(),
                    },
                ],
              ),
            ),
          ],
        );
  }

  Widget _buildActivityItem(UiJournalEntry entry) {
    return CommonClickable(
      onTap: () {
        Navigation.open(Paths.deviceStatsDetail, arguments: entry);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(
              entry.isBlocked()
                  ? CupertinoIcons.xmark_shield_fill
                  : CupertinoIcons.checkmark_shield_fill,
              color: entry.isBlocked() ? Colors.red : Colors.green,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DomainNameText(
                    domain: entry.domainName,
                    style: TextStyle(
                      fontSize: 16,
                      color: context.theme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    entry.timestampText,
                    style: TextStyle(
                      color: context.theme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              color: context.theme.textSecondary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: Center(
        child: Text(
          _selectedTab == ActivityTab.blocked ? "No blocked activity" : "No allowed activity",
          style: TextStyle(
            color: context.theme.textSecondary,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
