import 'package:flutter/material.dart';

import '../../common/widget/theme.dart';
import 'debugoptions.dart';

class DebugScreen extends StatefulWidget {
  final ScrollController controller;

  const DebugScreen({Key? key, required this.controller}) : super(key: key);

  @override
  State<StatefulWidget> createState() => DebugScreenState();
}

class DebugScreenState extends State<DebugScreen> {
  DebugScreenState();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return content();
  }

  Widget content() {
    final theme = Theme.of(context).extension<BlokadaTheme>()!;

    return Container(
      decoration: BoxDecoration(
          color: theme.panelBackground,
          borderRadius: BorderRadius.circular(10)),
      child: ListView(
        controller: widget.controller,
        padding: EdgeInsets.zero,
        children: [
          DebugOptions(),
        ],
      ),
    );
  }
}
