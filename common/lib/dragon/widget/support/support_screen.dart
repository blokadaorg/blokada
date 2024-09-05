import 'package:common/common/i18n.dart';
import 'package:common/common/widget/common_clickable.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/custom/custom.dart';
import 'package:common/dragon/widget/Support/Support_section.dart';
import 'package:common/dragon/widget/dialog.dart';
import 'package:common/dragon/widget/navigation.dart';
import 'package:common/dragon/widget/with_top_bar.dart';
import 'package:common/util/di.dart';
import 'package:common/util/trace.dart';
import 'package:flutter/cupertino.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => SupportScreenState();
}

class SupportScreenState extends State<SupportScreen> with TraceOrigin {
  late final _custom = dep<CustomStore>();

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
      title: "universal label help".i18n,
      child: const SupportSection(),
      topBarTrailing: _getAction(context),
    );
  }

  Widget _buildForTablet(BuildContext context) {
    return WithTopBar(
      title: "universal label help".i18n,
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
          // traceAs("sendLog", (trace) async {
          //   await _command.onCommand("log");
          // });
          showSupportDialog(context);
        },
        child: Icon(
          CupertinoIcons.ellipsis_circle,
          color: context.theme.accent,
        ));
  }
}
