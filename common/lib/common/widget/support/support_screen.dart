import 'package:common/common/module/support/support.dart';
import 'package:common/common/navigation.dart';
import 'package:common/common/widget/common_clickable.dart';
import 'package:common/common/widget/support/support_section.dart';
import 'package:common/common/widget/with_top_bar.dart';
import 'package:common/core/core.dart';
import 'package:flutter/material.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => SupportScreenState();
}

class SupportScreenState extends State<SupportScreen> with Logging {
  late final _support = Core.get<SupportActor>();

  Paths _path = Paths.support;
  Object? _arguments;

  @override
  void initState() {
    super.initState();
    // Navigation.openInTablet = (path, arguments) {
    //   if (!mounted) return;
    //   setState(() {
    //     _path = path;
    //     _arguments = arguments;
    //   });
    // };
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = isTabletMode(context);

    if (isTablet) return _buildForTablet(context);
    return _buildForPhone(context);
  }

  Widget _buildForPhone(BuildContext context) {
    return WithTopBar(
      title: "Chat with us",
      child: const SupportSection(),
      topBarTrailing: _getAction(context),
    );
  }

  Widget _buildForTablet(BuildContext context) {
    return WithTopBar(
      title: "Chat with us",
      topBarTrailing: _getAction(context),
      maxWidth: maxContentWidthTablet,
      child: Row(
        children: [
          const Expanded(
            flex: 1,
            child: SupportSection(),
          ),
          Expanded(
            flex: 1,
            child: _buildForPath(_path, _arguments),
          ),
        ],
      ),
    );
  }

  Widget _buildForPath(Paths path, Object? arguments) {
    switch (path) {
      // case Paths.SupportExceptions:
      //   return const ExceptionsSection(primary: false);
      default:
        return Container();
    }
  }

  Widget? _getAction(BuildContext context) {
    // return null;
    // if (_path != Paths.SupportExceptions) return null;

    return CommonClickable(
        onTap: () {
          // traceAs("sendLog", () async {
          //   await _command.onCommand("log");
          // });
          //showSupportDialog(context);
          Navigator.of(context).pop();
          _support.clearSession(Markers.userTap);
        },
        child: Text("End", style: TextStyle(color: Colors.red, fontSize: 17)));
  }
}
