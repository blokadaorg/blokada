import 'package:common/model/UiModel.dart';
import 'package:common/ui/radial_chart.dart';
import 'package:countup/countup.dart';
import 'package:flutter/material.dart';

import 'package:mobx/mobx.dart' as mobx;

import '../repo/Repos.dart';
import '../repo/StatsRepo.dart';

class RadialSegment extends StatefulWidget {

  const RadialSegment({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return RadialSegmentState();
  }

}

class RadialSegmentState extends State<RadialSegment> {

  final StatsRepo statsRepo = Repos.instance.stats;

  var stats = UiStats.empty();
  var blocked = 0.0;
  var allowed = 0.0;
  var total = 0.0;
  var lastBlocked = 0.0;
  var lastAllowed = 0.0;
  var lastTotal = 0.0;

  @override
  void initState() {
    super.initState();
    mobx.autorun((_) {
      setState(() {
        stats = statsRepo.stats;
        lastAllowed = allowed;
        lastBlocked = blocked;
        lastTotal = total;
        allowed = statsRepo.stats.rateAllowed.toDouble();
        blocked = statsRepo.stats.rateBlocked.toDouble();
        total = statsRepo.stats.rateTotal.toDouble();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8.0, left: 24.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text("24h", style: TextStyle(color: Color(0xff464646), fontSize: 18))
          ),
        ),
        Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: SizedBox(
                width: 260,
                height: 260,
                child: RadialChart(stats: stats)
              ), flex: 7),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Blocked", style: TextStyle(color: Color(0xffff3b30), fontSize: 20)),
                          Countup(
                            begin: lastBlocked,
                            end: blocked,
                            duration: Duration(seconds: 3),
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Allowed", style: TextStyle(color: Color(0xff33c75a), fontSize: 20)),
                          Countup(
                            begin: lastAllowed,
                            end: allowed,
                            duration: Duration(seconds: 3),
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Total", style: TextStyle(color: Color(0xff838383), fontSize: 20)),
                          Countup(
                            begin: lastTotal,
                            end: total,
                            duration: Duration(seconds: 3),
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            ]
        ),
      ],
    );
  }

}

String _formatCounter(int counter) {
  if (counter >= 1000000) {
    return "${(counter / 1000000.0).toStringAsFixed(2)}M";
  //} else if (counter >= 1000) {
  //  return "${(counter / 1000.0).toStringAsFixed(1)}K";
  } else {
    return "$counter";
  }
}
