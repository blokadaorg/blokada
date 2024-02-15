import 'package:common/mock/widget/common_divider.dart';
import 'package:common/service/I18nService.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:relative_scale/relative_scale.dart';
import 'package:vistraced/via.dart';

import '../../../../journal/channel.pg.dart';
import '../../../../stage/channel.pg.dart';
import '../../../../ui/stats/column_chart.dart';
import '../../../model.dart';
import '../../../widget.dart';
import '../home/top_bar.dart';
import 'activity_item.dart';
import 'radial_segment.dart';
import 'totalcounter.dart';

part 'stats_screen.g.dart';

class StatsScreen extends StatefulWidget {
  final FamilyDevice device;

  const StatsScreen({Key? key, required this.device}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _$StatsScreenState();
}

@Injected(onlyVia: true, immediate: true)
class StatsScreenState extends State<StatsScreen> with ViaTools<StatsScreen> {
  late final _stats = Via.as<UiStats>()..also(rebuild);
  late final _modal = Via.as<StageModal?>()..also(rebuild);

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
                        Container(
                          decoration: BoxDecoration(
                            color: context.theme.bgMiniCard,
                            borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12)),
                          ),
                          height: 12,
                        ),
                      ] +
                      _buildItems(context) +
                      [
                        Container(
                          decoration: BoxDecoration(
                            color: context.theme.bgMiniCard,
                            borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(12),
                                bottomRight: Radius.circular(12)),
                          ),
                          height: 12,
                        ),
                      ],
                ),
              ),
              TopBar(title: "Activity"),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildItems(BuildContext context) {
    return List.generate(100, (index) {
      return Container(
        color: context.theme.bgMiniCard,
        child: Column(children: [
          ActivityItem(
              entry: JournalEntry(
            domainName: index % 14 == 0
                ? "time.apple.com.sandbox.cdn.various.nice.domains.com"
                : "cdn$index.all.cdns.com",
            deviceName: "Alva",
            time: "${(index / 4).toInt()} minutes ago",
            requests: (index * 73) % 102,
            type: index % 4 == 0
                ? JournalEntryType.blocked
                : JournalEntryType.passedAllowed,
          )),
          index < 99 ? CommonDivider(indent: 60) : Container(),
        ]),
      );
    });
  }
}
