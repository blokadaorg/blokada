import 'package:common/common/i18n.dart';
import 'package:common/common/model.dart';
import 'package:common/common/widget/common_card.dart';
import 'package:common/common/widget/common_divider.dart';
import 'package:common/common/widget/minicard/header.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/dragon/customlist/controller.dart';
import 'package:common/dragon/filter/controller.dart';
import 'package:common/dragon/profile/controller.dart';
import 'package:common/dragon/widget/common/stats/action_info.dart';
import 'package:common/dragon/widget/common/stats/action_item.dart';
import 'package:common/dragon/widget/family/profile/profile_utils.dart';
import 'package:common/dragon/widget/navigation.dart';
import 'package:common/logger/logger.dart';
import 'package:common/util/di.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class StatsDetailSection extends StatefulWidget {
  final UiJournalEntry entry;
  final bool primary;

  const StatsDetailSection(
      {super.key, required this.entry, this.primary = true});

  @override
  State<StatefulWidget> createState() => StatsDetailSectionState();
}

class StatsDetailSectionState extends State<StatsDetailSection> with Logging {
  final _profile = dep<ProfileController>();
  final _filter = dep<FilterController>();
  final _custom = dep<CustomListController>();

  late JsonProfile? profile;

  @override
  void initState() {
    super.initState();
    try {
      profile = _profile.get(widget.entry.profileId);
    } catch (e) {
      profile = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ListView(
        primary: widget.primary,
        children: [
          SizedBox(height: getTopPadding(context)),
          CommonCard(
            bgColor: widget.entry.isBlocked() ? Colors.red : Colors.green,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(CupertinoIcons.shield,
                          color: Colors.white, size: 64),
                      Transform.translate(
                        offset: const Offset(0, -3),
                        child: Text(
                          (widget.entry.requests > 99)
                              ? "99"
                              : widget.entry.requests.toString(),
                          style: const TextStyle(
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
                              ? "activity request blocked".i18n
                              : "activity request allowed".i18n),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          CommonCard(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  MiniCardHeader(
                    text: "family stats label reason".i18n,
                    icon: CupertinoIcons.shield,
                    color: widget.entry.isBlocked() ? Colors.red : Colors.green,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("family stats label blocklist".i18n,
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
                                _filter.getFilterContainingList(
                                    widget.entry.listId),
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
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Container(
                          color: context.theme.divider.withOpacity(0.1),
                          width: 1,
                          height: 40,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("family stats label profile".i18n,
                              style: TextStyle(
                                  color: context.theme.textSecondary,
                                  fontSize: 12)),
                          profile != null
                              ? Row(
                                  children: [
                                    Icon(getProfileIcon(profile!.template),
                                        color:
                                            getProfileColor(profile!.template),
                                        size: 20),
                                    const SizedBox(width: 4),
                                    Text(
                                      profile!.displayAlias.i18n,
                                      style: TextStyle(
                                        color:
                                            getProfileColor(profile!.template),
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    Icon(CupertinoIcons.question_circle,
                                        color: context.theme.textSecondary,
                                        size: 20),
                                    const SizedBox(width: 4),
                                    Text(
                                      "family stats label profile unknown".i18n,
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
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
          Text("activity actions header".i18n,
              style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                    fontWeight: FontWeight.bold,
                  )),
          const SizedBox(height: 8),
          CommonCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  ActionItem(
                      icon: CupertinoIcons.shield_lefthalf_fill,
                      text: _custom.contains(widget.entry.domainName)
                          ? "family stats exceptions remove".i18n
                          : "family stats exceptions add".i18n,
                      onTap: () {
                        log(Markers.userTap).trace("addCustom", (m) async {
                          await _custom.addOrRemove(
                              widget.entry.domainName, Markers.userTap,
                              gotBlocked: widget.entry.isBlocked());
                          setState(() {});
                        });
                      }),
                  const CommonDivider(indent: 48),
                  ActionItem(
                      icon: CupertinoIcons.doc_on_clipboard,
                      text: "activity action copy to clipboard".i18n,
                      onTap: () {
                        Clipboard.setData(
                            ClipboardData(text: widget.entry.domainName));
                      }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
          Text("activity information header".i18n,
              style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                    fontWeight: FontWeight.bold,
                  )),
          const SizedBox(height: 8),
          CommonCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ActionInfo(
                    label: "activity domain name".i18n,
                    text: widget.entry.domainName,
                  ),
                  const CommonDivider(indent: 0),
                  ActionInfo(
                    label: "activity time of occurrence".i18n,
                    text: widget.entry.timestamp.toString(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
