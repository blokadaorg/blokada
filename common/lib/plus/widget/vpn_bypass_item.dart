import 'package:common/common/widget/common_clickable.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/core/core.dart';
import 'package:common/plus/module/bypass/bypass.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AppBypassItem extends StatelessWidget {
  final InstalledApp app;
  final Widget? icon;
  final bool showIcon;
  final bool showChevron;
  final VoidCallback onTap;

  const AppBypassItem({
    Key? key,
    required this.app,
    required this.icon,
    this.showIcon = true,
    this.showChevron = true,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CommonClickable(
      onTap: onTap,
      tapBorderRadius: BorderRadius.zero,
      tapBgColor: context.theme.divider.withOpacity(0.1),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        children: [
          (showIcon)
              ? Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: icon ??
                        Icon(Icons.web_stories_outlined,
                            color: context.theme.shadow),
                  ),
                )
              : Container(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app.appName ?? middleEllipsis(app.packageName),
                  style: const TextStyle(fontSize: 18),
                  overflow: TextOverflow.clip,
                ),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.only(right: 4.0),
                  child: Text(
                    app.packageName,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.theme.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          ),
          (showChevron)
              ? GestureDetector(
                  onTap: onTap,
                  child: Icon(
                    CupertinoIcons.chevron_forward,
                    size: 16,
                    color: context.theme.divider,
                  ),
                )
              : Container(),
        ],
      ),
    );
  }
}
