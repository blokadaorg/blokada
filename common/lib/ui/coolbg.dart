import 'package:common/logger/logger.dart';
import 'package:flutter/material.dart';

import 'background.dart';

class Coolbg extends StatefulWidget {
  const Coolbg({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _CoolbgState();
}

class _CoolbgState extends State<Coolbg>
    with TickerProviderStateMixin, Logging {
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        CoolBackground(),
        Padding(
          padding: const EdgeInsets.only(bottom: 128.0),
          child: Image.asset(
            "assets/images/blokada_logo.png",
            fit: BoxFit.cover,
            width: 128,
            height: 128,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }
}
