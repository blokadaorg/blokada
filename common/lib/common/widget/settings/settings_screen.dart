import 'package:common/common/dialog.dart';
import 'package:common/common/module/customlist/customlist.dart';
import 'package:common/common/module/support/support.dart';
import 'package:common/common/navigation.dart';
import 'package:common/common/widget/common_clickable.dart';
import 'package:common/common/widget/settings/exceptions_section.dart';
import 'package:common/common/widget/settings/retention_section.dart';
import 'package:common/common/widget/settings/settings_section.dart';
import 'package:common/common/widget/support/support_section.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/common/widget/with_top_bar.dart';
import 'package:common/core/core.dart';
import 'package:common/plus/widget/vpn_devices_section.dart';
import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> with Logging {
  late final _support = Core.get<SupportActor>();
  late final _custom = Core.get<CustomlistActor>();

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
      title: (Core.act.isFamily)
          ? "account action my account".i18n
          : "main tab settings".i18n,
      child: const SettingsSection(isHeader: false),
    );
  }

  Widget _buildForTablet(BuildContext context) {
    return WithTopBar(
      title: (Core.act.isFamily)
          ? "account action my account".i18n
          : "main tab settings".i18n,
      topBarTrailing: _path == Paths.support ? _getAction(context) : null,
      maxWidth: maxContentWidthTablet,
      child: Row(
        children: [
          const Expanded(
            flex: 1,
            child: SettingsSection(isHeader: false),
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
      case Paths.settingsRetention:
        return const RetentionSection(primary: false);
      case Paths.settingsVpnDevices:
        return const VpnDevicesSection();
      case Paths.support:
        return const SupportSection();
      default:
        return Container();
    }
  }

  Widget? _getAction(BuildContext context) {
    if (_path == Paths.settingsExceptions) {
      return _getExceptionsAction(context);
    } else if (_path == Paths.support) {
      return CommonClickable(
          onTap: () {
            Navigator.of(context).pop();
            _support.clearSession(Markers.userTap);
          },
          child: Text("support action end".i18n,
              style: const TextStyle(color: Colors.red, fontSize: 17)));
    } else {
      return null;
    }
  }

  Widget? _getExceptionsAction(BuildContext context) {
    return CommonClickable(
        onTap: () {
          showAddExceptionDialog(context, onConfirm: (entry) {
            log(Markers.userTap).trace("addCustom", (m) async {
              await _custom.addOrRemove(entry, m, gotBlocked: true);
            });
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
