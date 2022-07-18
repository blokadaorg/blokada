import 'package:common/radial_chart.dart';
import 'package:flutter/material.dart';

class RadialSegment extends StatefulWidget {
  final int blocked;
  final int allowed;

  const RadialSegment({Key? key,
    required this.blocked, required this.allowed
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => RadialSegmentState();
}

class RadialSegmentState extends State<RadialSegment> {

  @override
  void initState() {}

  @override
  Widget build(BuildContext context) {
    return Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: RadialChart(blocked: widget.blocked, allowed: widget.allowed), flex: 7),
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
                      Text("Total", style: TextStyle(color: Color(0xff5a5a5a), fontSize: 20)),
                      Text(_formatCounter(widget.blocked + widget.allowed), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900))
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Allowed", style: TextStyle(color: Color(0xff33c75a), fontSize: 20)),
                      Text(_formatCounter(widget.allowed), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900))
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Blocked", style: TextStyle(color: Color(0xffff3b30), fontSize: 20)),
                      Text(_formatCounter(widget.blocked), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900))
                    ],
                  ),
                )
              ],
            ),
          )
        ]
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
