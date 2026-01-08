import 'package:common/src/shared/ui/dialog.dart';
import 'package:common/src/features/journal/domain/journal.dart';
import 'package:common/src/features/stats/ui/stats_filter.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/shared/ui/two_letter_icon.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/app_variants/family/widget/profile/profile_button.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// A sub-dialog for selecting device to filter by (in StatsFilter)
class StatsDeviceFilter extends StatefulWidget {
  final StatsFilterController filter;

  const StatsDeviceFilter({super.key, required this.filter});

  @override
  StatsDeviceFilterState createState() => StatsDeviceFilterState();
}

class StatsDeviceFilterState extends State<StatsDeviceFilter> {
  final TextEditingController _ctrl = TextEditingController(text: "");
  late final _devices = Core.get<JournalDevicesValue>();

  @override
  void initState() {
    super.initState();
    _ctrl.text = widget.filter.draft.searchQuery;
    _ctrl.addListener(() {
      widget.filter.draft =
          widget.filter.draft.updateOnly(searchQuery: _ctrl.text.toLowerCase());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: ProfileButton(
                onTap: () {
                  setState(() {
                    widget.filter.draft =
                        widget.filter.draft.updateOnly(deviceName: "");
                  });
                },
                icon: CupertinoIcons.device_phone_portrait,
                iconColor: context.theme.divider,
                name: "activity device filter show all".i18n,
                borderColor: widget.filter.draft.deviceName.isBlank
                    ? context.theme.divider.withOpacity(0.20)
                    : null,
                tapBgColor: context.theme.divider.withOpacity(0.1),
                padding: const EdgeInsets.only(left: 12),
                trailing: const SizedBox(height: 48),
              ),
            ),
          ] +
          _buildDevices(context),
    );
  }

  List<Widget> _buildDevices(BuildContext context) {
    return _devices.now.map((device) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: ProfileButton(
          onTap: () {
            setState(() {
              widget.filter.draft =
                  widget.filter.draft.updateOnly(deviceName: device);
            });
          },
          leading: TwoLetterIconWidget(name: device),
          name: device,
          borderColor: widget.filter.draft.deviceName == device
              ? context.theme.divider.withOpacity(0.20)
              : null,
          tapBgColor: context.theme.divider.withOpacity(0.1),
          padding: const EdgeInsets.only(left: 12),
          trailing: const SizedBox(height: 48),
        ),
      );
    }).toList();
  }
}

void showStatsFilterDeviceDialog(BuildContext context,
    {required Function(JournalFilter) onConfirm,
    required StatsFilterController ctrl}) {
  showDefaultDialog(
    context,
    title: Text("account action devices".i18n),
    content: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        StatsDeviceFilter(filter: ctrl),
      ],
    ),
    actions: (context) => [
      TextButton(
        onPressed: () {
          Navigator.of(context).pop();
          showStatsFilterDialog(context, onConfirm: onConfirm);
        },
        child: Text("universal action cancel".i18n),
      ),
      TextButton(
        onPressed: () {
          Navigator.of(context).pop();
          onConfirm(ctrl.draft);
        },
        child: Text("universal action save".i18n),
      ),
    ],
  );
}
