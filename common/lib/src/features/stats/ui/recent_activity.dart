import 'package:common/src/shared/ui/blokada_segmented_control.dart';
import 'package:common/src/features/journal/domain/journal.dart';
import 'package:common/src/shared/automation/ids.dart';
import 'package:common/src/shared/layout/with_detail_pane.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:common/src/shared/ui/common_card.dart';
import 'package:common/src/shared/ui/common_clickable.dart';
import 'package:common/src/shared/ui/common_divider.dart';
import 'package:common/src/shared/ui/crossfade.dart';
import 'package:common/src/shared/ui/placeholder.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/features/stats/domain/controller.dart';
import 'package:common/src/features/stats/ui/stats_error.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Privacy Pulse's latest blocked and allowed requests. Draws the recent
/// section of [StatsController]; it fetches nothing itself.
class RecentActivity extends StatefulWidget {
  final StatsSection<RecentPreview> section;
  final VoidCallback onRetry;

  const RecentActivity({super.key, required this.section, required this.onRetry});

  @override
  State<StatefulWidget> createState() => RecentActivityState();
}

enum ActivityTab { blocked, allowed }

class RecentActivityState extends State<RecentActivity>
    with Logging, AutomaticKeepAliveClientMixin {
  ActivityTab _selectedTab = ActivityTab.blocked;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final data = widget.section.data;
    final isError = widget.section.isError;
    final isLoading = !isError && data == null;
    final currentEntries =
        (_selectedTab == ActivityTab.blocked ? data?.blocked : data?.allowed) ?? const [];

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
                "privacy pulse recents header".i18n,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: context.theme.textPrimary,
                ),
              ),
              MergeSemantics(
                child: Semantics(
                  identifier: AutomationIds.recentActivityShowAll,
                  button: true,
                  child: CommonClickable(
                    onTap: () {
                      Navigation.open(Paths.activity);
                    },
                    child: Text(
                      "privacy pulse timespan show all".i18n,
                      style: context.theme.linkStyle(const TextStyle(fontSize: 16)),
                    ),
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
                  child: BlokadaSegmentedControl<ActivityTab>(
                    groupValue: _selectedTab,
                    onValueChanged: (ActivityTab? value) {
                      if (value != null) {
                        setState(() => _selectedTab = value);
                      }
                    },
                    children: {
                      ActivityTab.blocked: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              CupertinoIcons.xmark_shield_fill,
                              color: Colors.red,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "privacy pulse tab blocked".i18n,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ActivityTab.allowed: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              CupertinoIcons.checkmark_shield_fill,
                              color: Colors.green,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "privacy pulse tab allowed".i18n,
                              style: const TextStyle(
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

              // Activity list or empty state
              Crossfade(
                switchKey: _selectedTab,
                child: Column(
                  children: [
                    if (isError)
                      StatsError(onRetry: widget.onRetry)
                    else if (isLoading)
                      // Shaped like the activity rows: up to five, title and time.
                      LoadingPlaceholder.rows(
                        count: 5,
                        rowHeight: 50,
                        dividerIndent: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      )
                    else if (currentEntries.isEmpty)
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
          ),
        ),
      ],
    );
  }

  Widget _buildActivityItem(UiJournalEntry entry) {
    // Highlight the entry whose domain detail is open in the pane — only
    // for selections that originated from a journal entry (this list), and
    // matched on the entry itself, so a same-named toplist selection does
    // not light this row up.
    final selectionArguments = PaneSelection.of(context)?.arguments;
    final isSelected = selectionArguments is UiJournalEntry &&
        selectionArguments.domainName == entry.domainName &&
        selectionArguments.timestamp == entry.timestamp;

    // Unified list-selection style: full-row square tint in the shared
    // accent-derived selection color, outside the clickable.
    return Container(
      color: isSelected ? context.theme.selection : null,
      child: CommonClickable(
      tapBorderRadius: BorderRadius.zero,
      onTap: () {
        Navigation.open(Paths.deviceStatsDetail, arguments: entry);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    middleEllipsis(entry.domainName, maxLength: 32),
                    style: TextStyle(
                      fontSize: 16,
                      color: context.theme.textPrimary,
                    ),
                    overflow: TextOverflow.clip,
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
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: Center(
        child: Text(
          "privacy pulse empty".i18n,
          style: TextStyle(
            color: context.theme.textSecondary,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
