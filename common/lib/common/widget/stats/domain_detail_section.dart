import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:common/common/dialog.dart';
import 'package:common/common/module/api/api.dart';
import 'package:common/common/module/customlist/customlist.dart';
import 'package:common/common/module/filter/filter.dart';
import 'package:common/common/module/journal/journal.dart';
import 'package:common/common/navigation.dart';
import 'package:common/common/widget/common_card.dart';
import 'package:common/common/widget/common_clickable.dart';
import 'package:common/common/widget/common_divider.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/core/core.dart';
import 'package:common/platform/device/device.dart';
import 'package:common/platform/stats/api.dart' as stats_api;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class DomainDetailSection extends StatefulWidget {
  final UiJournalMainEntry entry;
  final bool primary;
  final int level;
  final String domain;
  final List<UiJournalEntry>? subdomainEntries; // Deprecated, will be removed

  const DomainDetailSection({
    super.key,
    required this.entry,
    this.primary = true,
    required this.level,
    required this.domain,
    this.subdomainEntries,
  });

  @override
  State<StatefulWidget> createState() => DomainDetailSectionState();
}

class DomainDetailSectionState extends State<DomainDetailSection> with Logging {
  final TextEditingController _searchController = TextEditingController();
  List<UiJournalEntry> _filteredSubdomains = [];
  List<UiJournalEntry> _allSubdomains = [];
  bool _isLoading = true;

  late final _filter = Core.get<FilterActor>();
  late final _journal = Core.get<JournalActor>();
  late final _customlist = Core.get<CustomlistActor>();
  late final _customlistValue = Core.get<CustomListsValue>();
  late final _statsApi = Core.get<stats_api.StatsApi>();
  late final _accountId = Core.get<AccountId>();
  late final _device = Core.get<DeviceStore>();

  // Helper to count domain levels (dots + 1)
  int _getDomainLevel(String domain) {
    return domain.split('.').length;
  }

  // Extract second-level domain (e.g., "x.y.abc.apple.com" -> "abc.apple.com")
  String _getSecondLevelDomain(String domain) {
    final parts = domain.split('.');
    if (parts.length <= 3) {
      return domain; // Already second-level or TLD
    }
    // Take the last 3 parts for second-level domain
    return parts.sublist(parts.length - 3).join('.');
  }

  // Extract TLD domain for favicon (e.g., "ads.apple.com" -> "apple.com")
  String _getTldDomain(String domain) {
    final parts = domain.split('.');
    if (parts.length >= 2) {
      return '${parts[parts.length - 2]}.${parts[parts.length - 1]}';
    }
    return domain; // Return as-is if already a TLD
  }

  /// Check if domain has an existing rule in customlists
  /// Check both allowed and blocked lists, with any wildcard value
  bool _hasExistingRule() {
    final domain = widget.entry.domainName;
    // Check if domain exists in customlists with any wildcard value
    return _customlist.isInAllowedList(domain) || _customlist.isInBlockedList(domain);
  }

  String _getSubtitleText() {
    final actionText = widget.entry.action == UiJournalAction.block ? 'blocked' : 'allowed';
    final mainRequests = widget.entry.requests;
    final subdomainRequests = _allSubdomains.fold(0, (sum, e) => sum + e.requests);

    String baseText;
    String? listId;

    // Determine the base text based on requests distribution
    if (mainRequests == 0 && subdomainRequests > 0) {
      // Only subdomains have requests
      baseText =
          "$subdomainRequests requests to subdomains of ${widget.entry.domainName} were $actionText";
      // Use the first subdomain's listId if available
      listId = _allSubdomains.firstOrNull?.listId;
    } else if (mainRequests > 0 && subdomainRequests == 0) {
      // Only main domain has requests
      baseText = "$mainRequests requests to ${widget.entry.domainName} were $actionText";
      listId = widget.entry.listId;
    } else if (mainRequests > 0 && subdomainRequests > 0) {
      // Both have requests
      baseText =
          "$mainRequests requests to ${widget.entry.domainName} were $actionText and $subdomainRequests requests to its subdomains were also $actionText";
      listId = widget.entry.listId;
    } else {
      // Neither has requests (shouldn't normally happen)
      baseText = "No requests to ${widget.entry.domainName} or its subdomains";
      return baseText;
    }

    // Add blocklist info if domain was blocked and we have a listId
    if (widget.entry.action == UiJournalAction.block && listId != null) {
      // Check if it's a user rule (short ID)
      if (listId.length < 16) {
        return "$baseText by your rules";
      } else {
        // Get the blocklist name
        final listName = _filter.getFilterContainingList(listId);
        if (listName != "family stats label none".i18n && listName != "family stats title".i18n) {
          return "$baseText by $listName";
        }
      }
    }

    return baseText;
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterSubdomains);

    // Listen to customlist changes to rebuild the widget
    _customlistValue.onChange.listen((_) {
      if (mounted) setState(() {});
    });

    // Fetch subdomains from API
    _fetchSubdomains();
  }

  Future<void> _fetchSubdomains() async {
    await log(Markers.userTap).trace("fetchSubdomains", (m) async {
      setState(() {
        _isLoading = true;
      });

      try {
        final accountId = await _accountId.fetch(m);
        final deviceName = _device.deviceAlias;
        final actionStr = widget.entry.action == UiJournalAction.block ? "blocked" : "allowed";

        log(m).pair("level", widget.level);
        log(m).pair("domain", widget.domain);
        log(m).pair("action", actionStr);
        log(m).pair("deviceName", deviceName);

        final response = await _statsApi.getToplistV2(
          accountId: accountId,
          deviceName: deviceName,
          level: widget.level,
          domain: widget.domain,
          action: actionStr,
          limit: 50, // Fetch more subdomains
          range: "24h",
          m: m,
        );

        // Convert toplist entries to UiJournalEntry format
        final subdomains = <UiJournalEntry>[];
        for (var bucket in response.toplist) {
          for (var entry in bucket.entries) {
            // Skip the root entry (is_root = true)
            if (entry.isRoot == true) continue;

            subdomains.add(UiJournalEntry(
              deviceName: entry.deviceName ?? "",
              domainName: entry.name,
              action: widget.entry.action,
              listId: "",
              profileId: "",
              timestamp: DateTime.now(),
              requests: entry.count,
              modified: false,
            ));
          }
        }

        log(m).pair("subdomain_count", subdomains.length);

        if (mounted) {
          setState(() {
            _allSubdomains = subdomains;
            _filteredSubdomains = subdomains;
            _isLoading = false;
          });
        }
      } catch (e) {
        log(m).e(msg: "Failed to fetch subdomains", err: e);
        if (mounted) {
          setState(() {
            _allSubdomains = [];
            _filteredSubdomains = [];
            _isLoading = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterSubdomains);
    _searchController.dispose();
    super.dispose();
  }

  void _filterSubdomains() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredSubdomains = _allSubdomains;
      } else {
        _filteredSubdomains = _allSubdomains
            .where((subdomain) => subdomain.domainName.toLowerCase().contains(query))
            .toList();
      }
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

          // Header section with icon and domain info
          _buildHeader(),
          const SizedBox(height: 32),

          // Add Rule card
          _buildAddRuleCard(),
          const SizedBox(height: 16),

          // Subdomains section header
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Text(
              "Subdomains",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: context.theme.textPrimary,
              ),
            ),
          ),

          // Search bar (only show if more than 1 subdomain)
          if (_allSubdomains.length > 1) _buildSearchBar(),
          if (_allSubdomains.length > 1) const SizedBox(height: 16),

          // Subdomains list
          _buildSubdomainsList(),
          const SizedBox(height: 40), // Bottom padding like original
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          // Domain icon with favicon
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CachedNetworkImage(
              imageUrl:
                  'https://www.google.com/s2/favicons?domain=${_getTldDomain(widget.entry.domainName)}&sz=128',
              width: 80,
              height: 80,
              fit: BoxFit.contain,
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
              placeholder: (context, url) => Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: context.theme.textPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Icon(
                    CupertinoIcons.globe,
                    size: 40,
                    color: context.theme.textPrimary,
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: context.theme.textPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Icon(
                    CupertinoIcons.globe,
                    size: 40,
                    color: context.theme.textPrimary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Domain name
          Text(
            widget.entry.domainName,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: context.theme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),

          // Subtitle with stats
          Text(
            _getSubtitleText(),
            style: TextStyle(
              fontSize: 16,
              color: context.theme.textSecondary,
            ),
            textAlign: TextAlign.left,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return CommonCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.search,
            color: context.theme.textSecondary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search subdomains",
                hintStyle: TextStyle(
                  color: context.theme.textSecondary.withOpacity(0.6),
                  fontSize: 16,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: TextStyle(
                color: context.theme.textPrimary,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddRuleCard() {
    final hasRule = _hasExistingRule();

    return CommonCard(
      child: CommonClickable(
        onTap: () {
          showActivityRuleDialog(
            context,
            domainName: widget.entry.domainName,
            action: widget.entry.action,
            customlistActor: _customlist,
            onSelected: (option) {
              // TODO: Implement rule action based on selected option
            },
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  hasRule ? "Edit Rule" : "Add Rule",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: context.theme.textPrimary,
                  ),
                ),
              ),
              Icon(
                CupertinoIcons.chevron_right,
                color: context.theme.textSecondary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubdomainsList() {
    if (_isLoading) {
      return CommonCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_filteredSubdomains.isEmpty) {
      return CommonCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Center(
            child: Text(
              _searchController.text.isEmpty
                  ? "No subdomains found"
                  : "No subdomains match your search",
              style: TextStyle(
                color: context.theme.textSecondary,
                fontSize: 16,
              ),
            ),
          ),
        ),
      );
    }

    return CommonCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (int i = 0; i < _filteredSubdomains.length; i++) ...[
            _buildSubdomainItem(_filteredSubdomains[i]),
            if (i < _filteredSubdomains.length - 1) const CommonDivider(),
          ],
        ],
      ),
    );
  }

  Widget _buildSubdomainItem(UiJournalEntry subdomain) {
    // Level 2 items can navigate to level 3, level 3 items are not clickable
    final isLevel3 = widget.level >= 3;

    return CommonClickable(
      onTap: isLevel3 ? () {} : () {
        // Navigate to level 3 (exact hosts under this subdomain)
        final subdomainAsMain = UiJournalMainEntry(
          domainName: subdomain.domainName,
          requests: subdomain.requests,
          action: subdomain.action,
          listId: subdomain.listId,
        );

        Navigation.open(Paths.deviceStatsDetail, arguments: {
          'mainEntry': subdomainAsMain,
          'level': 3,  // Fetch level 3 (exact hosts)
          'domain': subdomain.domainName,  // Use subdomain as the domain context
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                subdomain.domainName,
                style: TextStyle(
                  fontSize: 16,
                  color: context.theme.textPrimary,
                ),
              ),
            ),
            Text(
              subdomain.requests.toString(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.theme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
