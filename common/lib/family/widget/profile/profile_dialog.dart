import 'package:common/common/dialog.dart';
import 'package:common/common/module/modal/modal.dart';
import 'package:common/common/widget/common_clickable.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/core/core.dart';
import 'package:common/family/module/device_v3/device.dart';
import 'package:common/family/module/family/family.dart';
import 'package:common/family/module/profile/profile.dart';
import 'package:common/family/widget/profile/profile_button.dart';
import 'package:common/family/widget/profile/profile_utils.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class ProfileDialog extends StatefulWidget {
  final DeviceTag deviceTag;
  final Function(JsonProfile)? onSelected;

  const ProfileDialog({Key? key, required this.deviceTag, this.onSelected})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => ProfileDialogState();
}

class ProfileDialogState extends State<ProfileDialog> with Disposables {
  late final _devices = Core.get<DeviceActor>();
  late final _profiles = Core.get<ProfileActor>();
  late final _familyDevices = Core.get<FamilyDevicesValue>();
  late final _modal = Core.get<CurrentModalValue>();

  late JsonDevice device;
  String? error;

  @override
  void initState() {
    super.initState();
    disposeLater(_familyDevices.onChange.listen(rebuild));
  }

  @override
  void dispose() {
    disposeAll();
    super.dispose();
  }

  setError(String error) {
    if (!mounted) return;
    setState(() {
      this.error = error;
    });
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() {
        this.error = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    device = _devices.getDevice(widget.deviceTag);
    final thisDevice =
        _familyDevices.now.getDevice(widget.deviceTag).thisDevice;

    return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
              thisDevice
                  ? Text("family profile dialog header this".i18n)
                  : Text("family profile dialog header"
                      .i18n
                      .withParams(device.alias)),
              const SizedBox(height: 32),
            ] +
            _profiles.profiles
                .map((it) => _buildProfileItem(context, device, it))
                .flatten()
                .toList() +
            _buildErrorMessageMaybe(context) +
            [
              const SizedBox(height: 40),
              CommonClickable(
                onTap: () {
                  _modal.change(Markers.userTap, Modal.familyAddProfile);
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
              Text("family profile action add".i18n,
                  style: const TextStyle(fontSize: 12)),
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
                  Navigator.of(context).pop();
                  _devices.changeDeviceProfile(device, it, Markers.userTap);
                }
              },
              icon: getProfileIcon(it.template),
              iconColor: getProfileColor(it.template),
              name: it.displayAlias.i18n,
              trailing: CommonClickable(
                onTap: () {
                  showRenameDialog(context, "profile", it.displayAlias,
                      onConfirm: (newName) {
                    _profiles.renameProfile(Markers.userTap, it, newName);
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
    late final device = Core.get<DeviceActor>();
    return Slidable(
      key: Key(it.alias),
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.3,
        children: [
          SlidableAction(
            onPressed: (c) async {
              try {
                await device.deleteProfile(Markers.userTap, it);
              } on ProfileInUseException catch (e) {
                setError("family profile error use".i18n);
              } catch (e) {
                setError("family profile error".i18n);
              }
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

  List<Widget> _buildErrorMessageMaybe(BuildContext context) {
    if (error == null) return [];
    return [
      const SizedBox(height: 16),
      Text(error!, style: const TextStyle(color: Colors.red)),
    ];
  }
}
