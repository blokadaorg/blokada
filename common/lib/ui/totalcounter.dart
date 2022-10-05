import 'package:countup/countup.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:ui' as ui;
import 'package:mobx/mobx.dart' as mobx;

import '../model/UiModel.dart';
import '../repo/Repos.dart';
import '../repo/StatsRepo.dart';

class TotalCounter extends StatefulWidget {

  TotalCounter({Key? key, required bool this.autoRefresh}) : super(key: key);

  final bool autoRefresh;

  @override
  State<StatefulWidget> createState() {
    return TotalCounterState(autoRefresh: this.autoRefresh);
  }

}

class TotalCounterState extends State<TotalCounter> {

  TotalCounterState({required bool this.autoRefresh});

  static const shareChannel = MethodChannel('share');

  final bool autoRefresh;

  final StatsRepo statsRepo = Repos.instance.stats;

  var allowed = 0.0;
  var blocked = 0;
  var lastAllowed = 0.0;
  var lastBlocked = 0;

  @override
  void initState() {
    super.initState();
    if (autoRefresh) {
      mobx.autorun((_) {
        setState(() {
          lastAllowed = allowed;
          lastBlocked = blocked;
          allowed = statsRepo.stats.totalAllowed.toDouble();
          blocked = statsRepo.stats.totalBlocked;
        });
      });
    }

  }

  Future<void> _shareCounter() async {
    try {
      await shareChannel.invokeMethod('shareCounter', blocked);
    } on PlatformException catch (e) {
      print("Failed to share counter: '${e.message}'.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 64.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 24.0),
              child: Text("All time", style: TextStyle(color: Color(0xff464646), fontSize: 18)),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8.0, left: 32.0),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Blocked", style: TextStyle(color: Color(0xffff3b30), fontSize: 20)),
                      Text(_formatCounter(blocked), style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900))
                      // Countup(
                      //   begin: lastBlocked,
                      //   end: blocked,
                      //   duration: Duration(seconds: 3),
                      //   style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900),
                      // ),
                    ]
                  ),
                  GestureDetector(
                    onTap: () { _shareCounter(); },
                    child: Padding(
                      padding: const EdgeInsets.only(left: 32.0),
                      child: Image(
                        width: 32,
                        height: 32,
                        image: AssetImage('assets/images/square.and.arrow.up.png'),
                        color: Theme.of(context).textTheme.bodyText1!.color,
                      ),
                    )
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

}

String _formatCounter(int counter) {
  if (counter >= 1000000) {
    return "${(counter / 1000000.0).toStringAsFixed(2)}M";
  } else if (counter >= 1000) {
     return "${(counter / 1000.0).toStringAsFixed(1)}K";
  } else {
    return "$counter";
  }
}
