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
import 'package:common/common/widget/domain_name_text.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/core/core.dart';
import 'package:common/platform/device/device.dart';
import 'package:common/platform/stats/api.dart' as stats_api;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DomainDetailSection extends StatefulWidget {
  final UiJournalMainEntry entry;
  final bool primary;
  final int level;
  final String domain;
  final bool fetchToplist;
  final List<UiJournalEntry>? subdomainEntries; // Deprecated, will be removed

  const DomainDetailSection({
    super.key,
    required this.entry,
    this.primary = true,
    required this.level,
    required this.domain,
    this.fetchToplist = true,
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
  int _parentCount = 0;  // Count for parent domain itself

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

  /// Trim parent domain suffix from subdomain name for display
  /// Example: "cdn.apple.com" with parent "apple.com" -> "cdn"
  String _trimParentSuffix(String subdomainName) {
    final parentDomain = widget.entry.domainName;
    final suffix = '.$parentDomain';

    if (subdomainName.endsWith(suffix)) {
      return subdomainName.substring(0, subdomainName.length - suffix.length);
    }

    // If it doesn't end with the parent, return as-is
    return subdomainName;
  }

  /// Get only the first part of domain (before first dot)
  /// Example: "www.apple.com" -> "www"
  String _getFirstSubdomain(String domainName) {
    final parts = domainName.split('.');
    return parts.isNotEmpty ? parts[0] : domainName;
  }

  String _getSubtitleText() {
    final actionText = widget.entry.action == UiJournalAction.block ? 'blocked' : 'allowed';
    final shortDomain = _getFirstSubdomain(widget.entry.domainName);

    // If fetchToplist is false, use widget.entry.requests directly
    if (!widget.fetchToplist) {
      final requests = widget.entry.requests;
      String baseText = "$requests requests to $shortDomain were $actionText";

      // Add blocklist info if domain was blocked and we have a listId
      if (widget.entry.action == UiJournalAction.block && widget.entry.listId != null && widget.entry.listId!.isNotEmpty) {
        // Check if it's a user rule (short ID)
        if (widget.entry.listId!.length < 16) {
          return "$baseText by your rules";
        } else {
          // Get the blocklist name
          final listName = _filter.getFilterContainingList(widget.entry.listId!);
          if (listName != "family stats label none".i18n && listName != "family stats title".i18n) {
            return "$baseText by $listName";
          }
        }
      }

      return baseText;
    }

    // Show loading state while fetching toplists
    if (_isLoading) {
      return "Loading...";
    }

    final mainRequests = _parentCount;  // Use parent_count from API for parent domain
    final subdomainRequests = _allSubdomains.fold(0, (sum, e) => sum + e.requests);

    String baseText;
    String? listId;

    // Determine the base text based on requests distribution
    if (mainRequests == 0 && subdomainRequests > 0) {
      // Only subdomains have requests
      baseText =
          "$subdomainRequests requests to subdomains of $shortDomain were $actionText";
      // Use the first subdomain's listId if available
      listId = _allSubdomains.firstOrNull?.listId;
    } else if (mainRequests > 0 && subdomainRequests == 0) {
      // Only main domain has requests
      baseText = "$mainRequests requests to $shortDomain were $actionText";
      listId = widget.entry.listId;
    } else if (mainRequests > 0 && subdomainRequests > 0) {
      // Both have requests
      baseText =
          "$mainRequests requests to $shortDomain were $actionText and $subdomainRequests requests to its subdomains were also $actionText";
      listId = widget.entry.listId;
    } else {
      // Neither has requests (shouldn't normally happen)
      baseText = "No requests to $shortDomain or its subdomains";
      return baseText;
    }

    // Add blocklist info if domain was blocked and we have a listId
    if (widget.entry.action == UiJournalAction.block && listId != null && listId.isNotEmpty) {
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

  bool _hasScheduledFetch = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterSubdomains);

    // Listen to customlist changes to rebuild the widget
    _customlistValue.onChange.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Schedule fetch to run after route animation completes
    if (!_hasScheduledFetch && widget.fetchToplist) {
      _hasScheduledFetch = true;
      final route = ModalRoute.of(context);
      if (route != null && route.animation != null) {
        // Listen for animation completion
        route.animation!.addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) {
            _fetchSubdomains();
          }
        });
      } else {
        // Fallback if no animation (shouldn't happen)
        _fetchSubdomains();
      }
    }
  }

  Future<void> _fetchSubdomains() async {
    await log(Markers.userTap).trace("fetchSubdomains", (m) async {
      setState(() {
        _isLoading = true;
      });

      try {
        final accountId = await _accountId.fetch(m);
        final deviceName = _device.deviceAlias;
        final isBlocked = widget.entry.action == UiJournalAction.block;

        log(m).pair("level", widget.level);
        log(m).pair("domain", widget.domain);
        log(m).pair("action", isBlocked ? "blocked" : "allowed+fallthrough");
        log(m).pair("deviceName", deviceName);

        // For blocked, fetch only "blocked" action
        // For allowed, fetch both "allowed" and "fallthrough" and merge
        final subdomains = <String, int>{};
        int parentCount = 0;

        if (isBlocked) {
          final response = await _statsApi.getToplistV2(
            accountId: accountId,
            deviceName: deviceName,
            level: widget.level,
            domain: widget.domain,
            action: "blocked",
            limit: 50,
            range: "24h",
            m: m,
          );

          log(m).pair("blocked_buckets", response.toplist.length);
          for (var bucket in response.toplist) {
            log(m).pair("blocked_bucket_action", bucket.action);
            log(m).pair("blocked_bucket_parentCount", bucket.parentCount);
            log(m).pair("blocked_bucket_entries", bucket.entries.length);

            // Extract parent count
            parentCount += bucket.parentCount ?? 0;

            for (var entry in bucket.entries) {
              log(m).pair("blocked_entry_name", entry.name);
              log(m).pair("blocked_entry_count", entry.count);
              log(m).pair("blocked_entry_isRoot", entry.isRoot);
              if (entry.isRoot == true) continue;
              subdomains[entry.name] = entry.count;
            }
          }
          log(m).pair("blocked_final_parentCount", parentCount);
          log(m).pair("blocked_final_subdomains", subdomains.length);
        } else {
          // Fetch both allowed and fallthrough, then merge
          final allowedResponse = await _statsApi.getToplistV2(
            accountId: accountId,
            deviceName: deviceName,
            level: widget.level,
            domain: widget.domain,
            action: "allowed",
            limit: 50,
            range: "24h",
            m: m,
          );

          final fallthroughResponse = await _statsApi.getToplistV2(
            accountId: accountId,
            deviceName: deviceName,
            level: widget.level,
            domain: widget.domain,
            action: "fallthrough",
            limit: 50,
            range: "24h",
            m: m,
          );

          log(m).pair("allowed_buckets", allowedResponse.toplist.length);
          log(m).pair("fallthrough_buckets", fallthroughResponse.toplist.length);

          // Merge allowed entries and parent counts
          for (var bucket in allowedResponse.toplist) {
            log(m).pair("allowed_bucket_action", bucket.action);
            log(m).pair("allowed_bucket_parentCount", bucket.parentCount);
            log(m).pair("allowed_bucket_entries", bucket.entries.length);

            parentCount += bucket.parentCount ?? 0;

            for (var entry in bucket.entries) {
              log(m).pair("allowed_entry_name", entry.name);
              log(m).pair("allowed_entry_count", entry.count);
              log(m).pair("allowed_entry_isRoot", entry.isRoot);
              if (entry.isRoot == true) continue;
              subdomains[entry.name] = (subdomains[entry.name] ?? 0) + entry.count;
            }
          }

          // Merge fallthrough entries and parent counts
          for (var bucket in fallthroughResponse.toplist) {
            log(m).pair("fallthrough_bucket_action", bucket.action);
            log(m).pair("fallthrough_bucket_parentCount", bucket.parentCount);
            log(m).pair("fallthrough_bucket_entries", bucket.entries.length);

            parentCount += bucket.parentCount ?? 0;

            for (var entry in bucket.entries) {
              log(m).pair("fallthrough_entry_name", entry.name);
              log(m).pair("fallthrough_entry_count", entry.count);
              log(m).pair("fallthrough_entry_isRoot", entry.isRoot);
              if (entry.isRoot == true) continue;
              subdomains[entry.name] = (subdomains[entry.name] ?? 0) + entry.count;
            }
          }

          log(m).pair("allowed_final_parentCount", parentCount);
          log(m).pair("allowed_final_subdomains", subdomains.length);
        }

        // Convert merged entries to UiJournalEntry format and sort by count
        final subdomainsList = subdomains.entries
            .map((e) => UiJournalEntry(
                  deviceName: "",
                  domainName: e.key,
                  action: widget.entry.action,
                  listId: "",
                  profileId: "",
                  timestamp: DateTime.now(),
                  requests: e.value,
                  modified: false,
                ))
            .toList();

        // Sort by request count descending
        subdomainsList.sort((a, b) => b.requests.compareTo(a.requests));

        log(m).pair("subdomain_count", subdomainsList.length);
        log(m).pair("parent_count", parentCount);

        if (mounted) {
          setState(() {
            _allSubdomains = subdomainsList;
            _filteredSubdomains = subdomainsList;
            _parentCount = parentCount;
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

          // When not fetching toplist (final level), show additional info sections
          if (!widget.fetchToplist) ...[
            // Filter/Blocklist info
            if (widget.entry.action == UiJournalAction.block &&
                widget.entry.listId != null &&
                widget.entry.listId!.isNotEmpty)
              _buildFilterInfoCard(),
            if (widget.entry.action == UiJournalAction.block &&
                widget.entry.listId != null &&
                widget.entry.listId!.isNotEmpty)
              const SizedBox(height: 16),

            // Actions section header
            Text(
              "activity actions header".i18n,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: context.theme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),

            // Actions card
            _buildActionsCard(),
            const SizedBox(height: 16),

            // Information section header
            Text(
              "activity information header".i18n,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: context.theme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),

            // Information card
            _buildInformationCard(),
          ],

          // Subdomains section (only show if fetchToplist is true)
          if (widget.fetchToplist) ...[
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
          ],
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

          // Domain name (long press to copy)
          GestureDetector(
            onLongPress: () {
              Clipboard.setData(ClipboardData(text: widget.entry.domainName));
            },
            child: DomainNameText(
              domain: widget.entry.domainName,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: context.theme.textPrimary,
              ),
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
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _filteredSubdomains.length,
        separatorBuilder: (context, index) => const CommonDivider(),
        itemBuilder: (context, index) {
          return _buildSubdomainItem(_filteredSubdomains[index]);
        },
      ),
    );
  }

  Widget _buildSubdomainItem(UiJournalEntry subdomain) {
    return CommonClickable(
      onTap: () {
        // Level 2: Navigate to level 3 (exact hosts)
        if (widget.level == 2) {
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
        }
        // Level 3: Navigate to DomainDetailSection with level 4
        else if (widget.level == 3) {
          final subdomainAsMain = UiJournalMainEntry(
            domainName: subdomain.domainName,
            requests: subdomain.requests,
            action: subdomain.action,
            listId: subdomain.listId,
          );

          Navigation.open(Paths.deviceStatsDetail, arguments: {
            'mainEntry': subdomainAsMain,
            'level': 4,  // Fetch level 4 (if any more subdomains)
            'domain': subdomain.domainName,
            'fetchToplist': false,  // Don't fetch at level 4 (final level)
          });
        }
        // Level 4+: Do nothing (shouldn't happen, but just in case)
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: DomainNameText(
                domain: subdomain.domainName,
                style: TextStyle(
                  fontSize: 16,
                  color: context.theme.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
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

  Widget _buildFilterInfoCard() {
    final listId = widget.entry.listId;
    if (listId == null || listId.isEmpty) return Container();

    String filterName;
    String filterLabel;

    // Check if it's a user rule (short ID)
    if (listId.length < 16) {
      filterName = "Your custom rules";
      filterLabel = "family stats label blocklist".i18n;
    } else {
      // Get the blocklist name
      filterName = _filter.getFilterContainingList(listId);
      filterLabel = "family stats label blocklist".i18n;
    }

    return CommonCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              CupertinoIcons.shield_lefthalf_fill,
              color: widget.entry.action == UiJournalAction.block
                  ? Colors.red
                  : Colors.green,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    filterLabel,
                    style: TextStyle(
                      color: context.theme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    filterName,
                    style: TextStyle(
                      color: context.theme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard() {
    return CommonCard(
      padding: EdgeInsets.zero,
      child: CommonClickable(
        onTap: () {
          Clipboard.setData(ClipboardData(text: widget.entry.domainName));
          // TODO: Maybe show a toast/snackbar confirming copy
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                CupertinoIcons.doc_on_clipboard,
                color: context.theme.textPrimary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "activity action copy to clipboard".i18n,
                  style: TextStyle(
                    fontSize: 16,
                    color: context.theme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInformationCard() {
    return CommonCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Domain name
            _buildInfoRow(
              label: "activity domain name".i18n,
              value: widget.entry.domainName,
            ),
            const SizedBox(height: 12),
            // Request count
            _buildInfoRow(
              label: "activity request count".i18n,
              value: widget.entry.requests.toString(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: context.theme.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: context.theme.textPrimary,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
