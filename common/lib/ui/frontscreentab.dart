import 'package:flutter/material.dart';

class FrontScreenTab extends StatefulWidget {
  @override
  _FrontScreenTab createState() => _FrontScreenTab();
}

class _FrontScreenTab extends State<FrontScreenTab> {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        decoration: BoxDecoration(color: Color(0xff181818),
            borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16))),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: SizedBox(
            width: 200,
            height: 30,
            child: Text("-"),
          ),
        ),
      ),
    );
  }
}
