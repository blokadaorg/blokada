import 'package:common/common/model.dart';
import 'package:common/common/widget/common_clickable.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/dragon/device/controller.dart';
import 'package:common/dragon/family/family.dart';
import 'package:common/dragon/profile/controller.dart';
import 'package:common/dragon/widget/add_profile_sheet.dart';
import 'package:common/dragon/widget/dialog.dart';
import 'package:common/dragon/widget/profile_button.dart';
import 'package:common/dragon/widget/profile_utils.dart';
import 'package:common/util/di.dart';
import 'package:common/util/mobx.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

class ProfileDialog extends StatefulWidget {
  final DeviceTag deviceTag;
  final Function(JsonProfile)? onSelected;

  const ProfileDialog({Key? key, required this.deviceTag, this.onSelected})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => ProfileDialogState();
}

class ProfileDialogState extends State<ProfileDialog> {
  late final _family = dep<FamilyStore>();
  late final _devices = dep<DeviceController>();
  late final _profiles = dep<ProfileController>();

  late JsonDevice device;

  @override
  void initState() {
    super.initState();
    reactionOnStore((_) => _family.devices, (_) => rebuild());
  }

  rebuild() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    device = _devices.getDevice(widget.deviceTag);

    return Column(
        children: [
              Text("Choose a profile to use for ${device.alias}."),
              const SizedBox(height: 32),
            ] +
            _profiles.profiles
                .map((it) => _buildProfileItem(context, device, it))
                .flatten()
                .toList() +
            [
              const SizedBox(height: 40),
              CommonClickable(
                onTap: () {
                  //Navigator.of(context).pop();
                  showCupertinoModalBottomSheet(
                    context: context,
                    duration: const Duration(milliseconds: 300),
                    backgroundColor: context.theme.bgColorCard,
                    builder: (context) => const AddProfileSheet(),
                  );
                },
                tapBgColor: context.theme.divider,
                tapBorderRadius: BorderRadius.circular(24),
                padding: EdgeInsets.zero,
                child: Container(
                  decoration: BoxDecoration(
                    color: context.theme.divider.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Icon(
                      CupertinoIcons.plus,
                      size: 16,
                      color: context.theme.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text("Add new profile", style: TextStyle(fontSize: 12)),
            ]);
  }

  List<Widget> _buildProfileItem(
      BuildContext context, JsonDevice device, JsonProfile it) {
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: _wrapInDismissible(
            context,
            it,
            ProfileButton(
              onTap: () {
                if (widget.onSelected != null) {
                  widget.onSelected!.invoke(it);
                } else {
                  _devices.changeDeviceProfile(device, it);
                }
              },
              icon: getProfileIcon(it.template),
              iconColor: getProfileColor(it.template),
              name: it.displayAlias,
              trailing: CommonClickable(
                onTap: () {
                  showRenameDialog(context, "profile", it.displayAlias,
                      onConfirm: (newName) {
                    _profiles.renameProfile(it, newName);
                  });
                },
                padding: const EdgeInsets.all(16),
                child: Icon(
                  CupertinoIcons.pencil,
                  size: 16,
                  color: context.theme.textSecondary,
                ),
              ),
              borderColor: it.profileId == device.profileId
                  ? getProfileColor(it.template).withOpacity(0.30)
                  : null,
              tapBgColor: context.theme.divider.withOpacity(0.1),
              padding: const EdgeInsets.only(left: 12),
            )),
      ),
    ];
  }

  Widget _wrapInDismissible(
      BuildContext context, JsonProfile it, Widget child) {
    late final device = dep<DeviceController>();
    return Slidable(
      key: Key(it.alias),
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.3,
        children: [
          SlidableAction(
            onPressed: (c) {
              device.deleteProfile(it);
            },
            backgroundColor: Colors.red.withOpacity(0.80),
            foregroundColor: Colors.white,
            icon: CupertinoIcons.delete,
            borderRadius: const BorderRadius.all(Radius.circular(8)),
          ),
        ],
      ),
      child: child,
    );
  }
}
