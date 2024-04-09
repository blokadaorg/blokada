import 'package:common/common/model.dart';
import 'package:common/common/widget/common_divider.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/dragon/journal/api.dart';
import 'package:common/dragon/widget/home/top_bar.dart';
import 'package:common/dragon/widget/stats/activity_item.dart';
import 'package:common/journal/channel.pg.dart';
import 'package:common/journal/json.dart';
import 'package:common/util/di.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class StatsScreen extends StatefulWidget {
  final DeviceTag deviceTag;

  const StatsScreen({Key? key, required this.deviceTag}) : super(key: key);

  @override
  State<StatefulWidget> createState() => StatsScreenState();
}

class StatsScreenState extends State<StatsScreen> {
  final ScrollController _scrollController = ScrollController();
  late final _journal = dep<JournalApi>();

  bool _isReady = false;
  late List<JsonJournalEntry> _entries;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateTopBar);
    Future(() async {
      final e = await _journal.fetch(widget.deviceTag);
      setState(() {
        _isReady = true;
        _entries = e;
      });
    });
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
                child: !_isReady
                    ? Container()
                    : ListView(
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
    return _entries.mapIndexed((index, it) {
      //return List.generate(100, (index) {
      return Container(
        color: context.theme.bgMiniCard,
        child: Column(children: [
          ActivityItem(
              entry: JournalEntry(
            domainName: it.domainName,
            deviceName: it.deviceName,
            time: "${(index / 4).toInt()} minutes ago",
            requests: 1,
            type: it.action == "block"
                ? JournalEntryType.blocked
                : JournalEntryType.passedAllowed,
          )),
          index < _entries.length - 1
              ? const CommonDivider(indent: 60)
              : Container(),
        ]),
      );
    }).toList();
  }
}
