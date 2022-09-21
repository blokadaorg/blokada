import 'package:common/ui/power_button.dart';
import 'package:flutter/material.dart';

import '../model/AppModel.dart';
import 'samples/pie_chart_sample1.dart';
import 'samples/pie_chart_sample2.dart';
import 'samples/pie_chart_sample3.dart';

class Home extends StatelessWidget {

  const Home({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
        begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color(0xff054079),
            Color(0xff000000),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 100.0),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Image.asset("assets/images/header.png",
              width: 220,
              height: 60,
              fit: BoxFit.scaleDown,
            ),
            Align(
              alignment: AlignmentDirectional(0, 0),
              child: Text(
                'ACTIVE',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge
              ),
            ),
            Spacer(),
            Expanded(
              child: PowerButton(),
            ),
            Spacer(),
            Text(
              '1337 ads and trackers blocked',
              style: Theme.of(context).textTheme.bodyLarge
            ),
            Spacer(),
          ],
        ),
      ),
    );
  }
}
