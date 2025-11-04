import 'package:common/common/module/journal/journal.dart';
import 'package:common/common/navigation.dart';
import 'package:common/common/widget/common_card.dart';
import 'package:common/common/widget/common_clickable.dart';
import 'package:common/common/widget/common_divider.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/core/core.dart';
import 'package:common/family/module/stats/stats.dart';
import 'package:common/platform/stats/stats.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

class TopDomains extends StatefulWidget {
  const TopDomains({super.key});

  @override
  State<StatefulWidget> createState() => TopDomainsState();
}

enum ToplistTab { blocked, allowed }

class TopDomainsState extends State<TopDomains> {
  ToplistTab _selectedTab = ToplistTab.blocked;
  late final _statsStore = Core.get<StatsStore>();
  late final _journal = Core.get<JournalActor>();

  List<UiToplistEntry> get _blockedDomains {
    final stats = _statsStore.stats;
    return stats.toplist.where((entry) => entry.blocked).take(12).toList();
  }

  List<UiToplistEntry> get _allowedDomains {
    final stats = _statsStore.stats;
    return stats.toplist.where((entry) => !entry.blocked).take(12).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final currentDomains = _selectedTab == ToplistTab.blocked ? _blockedDomains : _allowedDomains;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Toplists",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: context.theme.textPrimary,
                    ),
                  ),
                  Text(
                    "24h",
                    style: TextStyle(
                      fontSize: 16,
                      color: context.theme.textSecondary,
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
                      child: CupertinoSlidingSegmentedControl<ToplistTab>(
                        groupValue: _selectedTab,
                        onValueChanged: (ToplistTab? value) {
                          if (value != null) {
                            setState(() => _selectedTab = value);
                          }
                        },
                        children: {
                          ToplistTab.blocked: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.xmark_shield_fill,
                                  color: Colors.red,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "Blocked",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ToplistTab.allowed: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.checkmark_shield_fill,
                                  color: Colors.green,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "Allowed",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        },
                      ),
                    ),
                  ),

                  const CommonDivider(),

                  // Domain list, loading state, or empty state
                  if (_statsStore.toplistsLoading && currentDomains.isEmpty)
                    _buildLoadingState()
                  else if (currentDomains.isEmpty)
                    _buildEmptyState()
                  else
                    for (int i = 0; i < currentDomains.length; i++) ...{
                      _buildDomainItem(currentDomains[i]),
                      if (i < currentDomains.length - 1) const CommonDivider(),
                    },
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildDomainItem(UiToplistEntry entry) {
    final domainName = entry.company ?? entry.tld ?? "Unknown";

    return CommonClickable(
      onTap: () {
        // Convert toplist entry to UiJournalMainEntry for navigation
        final mainEntry = UiJournalMainEntry(
          domainName: domainName,
          requests: entry.value,
          action: entry.blocked ? UiJournalAction.block : UiJournalAction.allow,
          listId: null,
        );

        Navigation.open(Paths.deviceStatsDetail, arguments: {
          'mainEntry': mainEntry,
          'level': 2,  // Fetch level 2 (subdomains under this eTLD+1)
          'domain': domainName,  // Domain to fetch subdomains for
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                middleEllipsis(domainName),
                style: TextStyle(
                  fontSize: 16,
                  color: context.theme.textPrimary,
                ),
                overflow: TextOverflow.clip,
              ),
            ),
            Text(
              entry.value.toString(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.theme.textSecondary,
              ),
            ),
            SizedBox(width: 8),
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
          _selectedTab == ToplistTab.blocked ? "No blocked domains found" : "No allowed domains found",
          style: TextStyle(
            color: context.theme.textSecondary,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
