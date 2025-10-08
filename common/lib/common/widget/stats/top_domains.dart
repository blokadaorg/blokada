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

class TopDomainsState extends State<TopDomains> {
  bool _showBlocked = true;
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
        final currentDomains = _showBlocked ? _blockedDomains : _allowedDomains;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: Text(
                "Toplists",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: context.theme.textPrimary,
                ),
              ),
            ),

            // Tabbed card
            CommonCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  // Tab row
                  Row(
                    children: [
                      Expanded(
                        child: _buildTab(
                          "Blocked",
                          _showBlocked,
                          () => setState(() => _showBlocked = true),
                          Color(0xffff3b30),
                        ),
                      ),
                      Expanded(
                        child: _buildTab(
                          "Allowed",
                          !_showBlocked,
                          () => setState(() => _showBlocked = false),
                          Color(0xff33c75a),
                        ),
                      ),
                    ],
                  ),

                  const CommonDivider(),

                  // Domain list, loading state, or empty state
                  if (_statsStore.toplistsLoading)
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

  Widget _buildTab(String title, bool isSelected, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.05) : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: isSelected ? color : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isSelected ? color : context.theme.textSecondary,
            ),
          ),
        ),
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
                domainName,
                style: TextStyle(
                  fontSize: 16,
                  color: context.theme.textPrimary,
                ),
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
          _showBlocked ? "No blocked domains found" : "No allowed domains found",
          style: TextStyle(
            color: context.theme.textSecondary,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

