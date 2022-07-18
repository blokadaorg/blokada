import 'package:flutter/material.dart';

class Selector extends StatefulWidget {
  @override
  _SelectorState createState() => _SelectorState();
}

class _SelectorState extends State<Selector> {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.only(left: 8.0, right: 4.0),
            child: OutlinedButton(
                onPressed: () {
                  debugPrint('Received click');
                },
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                    Padding(
                      padding: EdgeInsets.only(right: 8.0),
                      child: Icon(
                        Icons.timelapse,
                        color: Colors.white12,
                        size: 30.0,
                      ),
                    ),
                    Expanded(child: Text('24h')),
                  ]),
                )),
          ),
        ),
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.only(left: 4.0, right: 8.0),
            child: OutlinedButton(
                onPressed: () {
                  debugPrint('Received click');
                },
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                  child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Padding(
                          padding: EdgeInsets.only(right: 8.0),
                          child: Icon(
                            Icons.smartphone,
                            color: Colors.white12,
                            size: 30.0,
                          ),
                        ),
                        Expanded(child: Text('All devices')),
                      ]),
                )),
          ),
        ),
      ],
    );
  }
}
