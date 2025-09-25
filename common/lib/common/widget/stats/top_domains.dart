import 'package:common/common/widget/common_card.dart';
import 'package:common/common/widget/common_clickable.dart';
import 'package:common/common/widget/common_divider.dart';
import 'package:common/common/widget/theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class TopDomains extends StatefulWidget {
  const TopDomains({super.key});

  @override
  State<StatefulWidget> createState() => TopDomainsState();
}

class TopDomainsState extends State<TopDomains> {
  bool _showBlocked = true;

  // Mock data
  final List<DomainEntry> _blockedDomains = [
    DomainEntry('apple.com', 15),
    DomainEntry('facebook.net', 12),
    DomainEntry('example.org', 9),
  ];

  final List<DomainEntry> _allowedDomains = [
    DomainEntry('google.com', 25),
    DomainEntry('github.com', 18),
    DomainEntry('stackoverflow.com', 14),
  ];

  @override
  Widget build(BuildContext context) {
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

              // Domain list
              for (int i = 0; i < (_showBlocked ? _blockedDomains : _allowedDomains).length; i++) ...{
                _buildDomainItem((_showBlocked ? _blockedDomains : _allowedDomains)[i]),
                if (i < (_showBlocked ? _blockedDomains : _allowedDomains).length - 1) const CommonDivider(),
              },
            ],
          ),
        ),
      ],
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

  Widget _buildDomainItem(DomainEntry domain) {
    return CommonClickable(
      onTap: () {
        // TODO: Navigate to domain details
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                domain.name,
                style: TextStyle(
                  fontSize: 16,
                  color: context.theme.textPrimary,
                ),
              ),
            ),
            Text(
              domain.count.toString(),
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
}

class DomainEntry {
  final String name;
  final int count;

  DomainEntry(this.name, this.count);
}