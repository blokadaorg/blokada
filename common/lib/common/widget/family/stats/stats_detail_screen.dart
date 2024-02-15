import 'package:common/common/widget.dart';
import 'package:common/journal/channel.pg.dart';
import 'package:common/journal/journal.dart';
import 'package:common/mock/widget/common_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../mock/widget/action_info.dart';
import '../../../../mock/widget/action_item.dart';
import '../../../../mock/widget/common_divider.dart';
import '../../../../mock/widget/common_item.dart';
import '../home/top_bar.dart';

class StatsDetailScreen extends StatefulWidget {
  final JournalEntry entry;

  const StatsDetailScreen({super.key, required this.entry});

  @override
  State<StatefulWidget> createState() => StatsDetailScreenState();
}

class StatsDetailScreenState extends State<StatsDetailScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateTopBar);
  }

  void _updateTopBar() {
    Provider.of<TopBarController>(context, listen: false)
        .updateScrollPos(_scrollController.offset);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateTopBar);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: context.theme.bgColor,
        child: PrimaryScrollController(
          controller: _scrollController,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ListView(
                  primary: true,
                  children: [
                    SizedBox(height: 60),
                    CommonCard(
                      bgColor:
                          widget.entry.isBlocked() ? Colors.red : Colors.green,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 12),
                        child: Row(
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(CupertinoIcons.shield,
                                    color: Colors.white, size: 64),
                                Transform.translate(
                                  offset: const Offset(0, -3),
                                  child: Text(
                                    (widget.entry.requests > 99)
                                        ? "99"
                                        : widget.entry.requests.toString(),
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              flex: 1,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(widget.entry.domainName,
                                      style: const TextStyle(
                                          fontSize: 24, color: Colors.white),
                                      overflow: TextOverflow.ellipsis),
                                  Text(
                                    (widget.entry.isBlocked()
                                        ? "This request has been blocked."
                                        : "This request has been allowed."),
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                    CommonCard(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          children: [
                            MiniCardHeader(
                              text: "Reason",
                              icon: CupertinoIcons.shield,
                              color: widget.entry.isBlocked()
                                  ? Colors.red
                                  : Colors.green,
                            ),
                            SizedBox(height: 24),
                            Row(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Blocklist",
                                        style: TextStyle(
                                            color: context.theme.textSecondary,
                                            fontSize: 12)),
                                    Row(
                                      children: [
                                        // Icon(CupertinoIcons.eye_slash_fill,
                                        //     color: context.theme.textSecondary,
                                        //     size: 20),
                                        // const SizedBox(width: 4),
                                        Text(
                                          widget.entry.isBlocked()
                                              ? "Ad blocking"
                                              : "None",
                                          style: TextStyle(
                                            color: context.theme.textSecondary,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0),
                                  child: Container(
                                    color:
                                        context.theme.divider.withOpacity(0.1),
                                    width: 1,
                                    height: 40,
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Profile",
                                        style: TextStyle(
                                            color: context.theme.textSecondary,
                                            fontSize: 12)),
                                    Row(
                                      children: [
                                        Icon(CupertinoIcons.person_solid,
                                            color: Colors.green, size: 20),
                                        const SizedBox(width: 4),
                                        Text(
                                          "Child",
                                          style: TextStyle(
                                            color: Colors.green,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 40),
                    Text("Actions",
                        style:
                            Theme.of(context).textTheme.headlineSmall!.copyWith(
                                  fontWeight: FontWeight.bold,
                                )),
                    SizedBox(height: 8),
                    CommonCard(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          children: [
                            ActionItem(
                                icon: CupertinoIcons.shield_slash,
                                text: widget.entry.isBlocked()
                                    ? "Add to Allowed"
                                    : "Add to Blocked",
                                onTap: () {}),
                            CommonDivider(indent: 48),
                            ActionItem(
                                icon: CupertinoIcons.doc_on_clipboard,
                                text: "Copy name to Clipboard",
                                onTap: () {}),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 40),
                    Text("Information",
                        style:
                            Theme.of(context).textTheme.headlineSmall!.copyWith(
                                  fontWeight: FontWeight.bold,
                                )),
                    SizedBox(height: 8),
                    CommonCard(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ActionInfo(
                              label: "Full name",
                              text: widget.entry.domainName,
                            ),
                            CommonDivider(indent: 0),
                            ActionInfo(
                              label: "Time",
                              text: "21/03/2024, 13:23:34",
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 40),
                  ],
                ),
              ),
              TopBar(title: "Details"),
            ],
          ),
        ),
      ),
    );
  }
}
