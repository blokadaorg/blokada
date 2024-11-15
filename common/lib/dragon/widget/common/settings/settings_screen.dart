import 'package:common/common/i18n.dart';
import 'package:common/common/widget/common_clickable.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/custom/custom.dart';
import 'package:common/dragon/widget/common/settings/exceptions_section.dart';
import 'package:common/dragon/widget/common/settings/settings_section.dart';
import 'package:common/dragon/widget/common/with_top_bar.dart';
import 'package:common/dragon/widget/dialog.dart';
import 'package:common/dragon/widget/navigation.dart';
import 'package:common/logger/logger.dart';
import 'package:common/util/di.dart';
import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> with Logging {
  late final _custom = dep<CustomStore>();

  Paths _path = Paths.settingsExceptions;
  Object? _arguments;

  @override
  void initState() {
    super.initState();
    Navigation.openInTablet = (path, arguments) {
      if (!mounted) return;
      setState(() {
        _path = path;
        _arguments = arguments;
      });
    };
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = isTabletMode(context);

    if (isTablet) return _buildForTablet(context);
    return _buildForPhone(context);
  }

  Widget _buildForPhone(BuildContext context) {
    return WithTopBar(
      title: "account action my account".i18n,
      child: const SettingsSection(),
    );
  }

  Widget _buildForTablet(BuildContext context) {
    return WithTopBar(
      title: "account action my account".i18n,
      //topBarTrailing: _getAction(context),
      maxWidth: maxContentWidthTablet,
      child: Row(
        children: [
          const Expanded(
            flex: 1,
            child: SettingsSection(),
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
      case Paths.settingsExceptions:
        return const ExceptionsSection(primary: false);
      default:
        return Container();
    }
  }

  Widget? _getAction(BuildContext context) {
    if (_path != Paths.settingsExceptions) return null;

    return CommonClickable(
        onTap: () {
          showAddExceptionDialog(context, onConfirm: (entry) {
            _custom.allow(entry, Markers.userTap);
          });
        },
        child: Text(
          "Add",
          style: TextStyle(
            color: context.theme.accent,
            fontSize: 17,
          ),
        ));
  }
}
