import 'package:countup/countup.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:ui' as ui;
import 'package:mobx/mobx.dart' as mobx;

import '../model/UiModel.dart';
import '../repo/Repos.dart';
import '../repo/StatsRepo.dart';

class TotalCounter extends StatefulWidget {

  TotalCounter({
    Key? key
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return TotalCounterState();
  }

}

class TotalCounterState extends State<TotalCounter> {

  final StatsRepo statsRepo = Repos.instance.stats;

  var allowed = 0.0;
  var blocked = 0.0;
  var lastAllowed = 0.0;
  var lastBlocked = 0.0;

  @override
  void initState() {
    super.initState();
    mobx.autorun((_) {
      setState(() {
        lastAllowed = allowed;
        lastBlocked = blocked;
        allowed = statsRepo.stats.totalAllowed.toDouble();
        blocked = statsRepo.stats.totalBlocked.toDouble();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 32.0, bottom: 16.0),
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
              padding: const EdgeInsets.only(top: 16.0, left: 32.0),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 2,
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
                      ]
                    ),
                  ),
                  Expanded(
                    flex: 3,
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
                        ]
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Image(
                      width: 32,
                      height: 32,
                      image: AssetImage('assets/images/square.and.arrow.up.png')
                    ),
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