import 'package:common/common/widget/theme.dart';
import 'package:common/core/core.dart';
import 'package:common/v6/widget/home/home_section.dart';
import 'package:flutter/material.dart';

class V6HomeScreen extends StatefulWidget {
  const V6HomeScreen({Key? key}) : super(key: key);

  @override
  State<V6HomeScreen> createState() => _V6HomeScreenState();
}

class _V6HomeScreenState extends State<V6HomeScreen> with Logging {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.theme.bgColorHome3,
      body: V6HomeSection(),
    );
  }
}
