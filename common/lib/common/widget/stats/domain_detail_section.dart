import 'package:cached_network_image/cached_network_image.dart';
import 'package:common/common/module/journal/journal.dart';
import 'package:common/common/navigation.dart';
import 'package:common/common/widget/common_card.dart';
import 'package:common/common/widget/common_clickable.dart';
import 'package:common/common/widget/common_divider.dart';
import 'package:common/common/widget/theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class DomainDetailSection extends StatefulWidget {
  final UiJournalMainEntry entry;
  final bool primary;
  final List<UiJournalEntry>? subdomainEntries;

  const DomainDetailSection({
    super.key,
    required this.entry,
    this.primary = true,
    this.subdomainEntries,
  });

  @override
  State<StatefulWidget> createState() => DomainDetailSectionState();
}

class DomainDetailSectionState extends State<DomainDetailSection> {
  final TextEditingController _searchController = TextEditingController();
  List<UiJournalEntry> _filteredSubdomains = [];
  List<UiJournalEntry> _allSubdomains = [];

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

  @override
  void initState() {
    super.initState();
    // Default to empty list if not provided
    _allSubdomains = widget.subdomainEntries ?? [];
    _filteredSubdomains = _allSubdomains;
    _searchController.addListener(_filterSubdomains);
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

          // Subdomains list
          _buildSubdomainsList(),
          const SizedBox(height: 16),

          // Search bar
          _buildSearchBar(),
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
            imageUrl: 'https://www.google.com/s2/favicons?domain=${widget.entry.domainName}&sz=128',
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
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: context.theme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),

        // Subtitle with stats
        Text(
          "${widget.entry.requests} requests to subdomains of ${widget.entry.domainName} were ${widget.entry.action == UiJournalAction.block ? 'blocked' : 'allowed'}",
          style: TextStyle(
            fontSize: 16,
            color: context.theme.textSecondary,
          ),
          textAlign: TextAlign.center,
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
    return CommonCard(
      child: CommonClickable(
        onTap: () {
          // TODO: Implement add rule functionality
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  "Add Rule",
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
    if (_filteredSubdomains.isEmpty) {
      return CommonCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Center(
            child: Text(
              _searchController.text.isEmpty ? "No subdomains found" : "No subdomains match your search",
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
    // Check if current main entry is already second-level (3 parts)
    final currentLevel = _getDomainLevel(widget.entry.domainName);
    final isSecondLevel = currentLevel >= 3;

    // If we're at second level, items are not clickable but keep styling
    if (isSecondLevel) {
      return CommonClickable(
        onTap: () {}, // Empty function - no tap handler
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

    // Otherwise, make it clickable and navigate to second-level
    return CommonClickable(
      onTap: () {
        // Extract second-level domain from the clicked subdomain
        final targetDomain = _getSecondLevelDomain(subdomain.domainName);

        // Create a MainEntry for the second-level domain
        final subdomainAsMain = UiJournalMainEntry(
          domainName: targetDomain,
          requests: subdomain.requests,
          action: subdomain.action,
        );

        // Pass a custom object to indicate we want to use subdomain as-is
        Navigation.open(Paths.deviceStatsDetail, arguments: {
          'mainEntry': subdomainAsMain,
          'isSubdomain': true,
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