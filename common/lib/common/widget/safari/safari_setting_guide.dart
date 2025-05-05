import 'package:common/common/widget/theme.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SafariSettingGuideWidget extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? edgeText;
  final Widget? iconReplacement;
  final IconData? icon;
  final Widget? widgetRight;
  final bool centerTitle;

  const SafariSettingGuideWidget({
    Key? key,
    required this.title,
    this.subtitle,
    this.edgeText,
    this.iconReplacement,
    this.icon,
    this.widgetRight,
    this.centerTitle = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.theme.bgColorHome2.lighten(2),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Container(
          decoration: BoxDecoration(
            color: context.theme.panelBackground.lighten(8),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                (icon != null)
                    ? Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: null,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(3.0),
                          child: Icon(
                            size: 16,
                            icon!,
                            color: context.theme.textPrimary,
                          ),
                        ),
                      )
                    : ((iconReplacement != null)
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: iconReplacement!,
                          )
                        : Container()),
                ((icon != null || iconReplacement != null) && !centerTitle)
                    ? const SizedBox(width: 12)
                    : Container(),
                Flexible(
                  child: Column(
                    crossAxisAlignment: (centerTitle)
                        ? CrossAxisAlignment.center
                        : CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500),
                          textAlign: (centerTitle)
                              ? TextAlign.center
                              : TextAlign.start),
                      (subtitle != null)
                          ? Text(subtitle!,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: context.theme.textSecondary))
                          : Container(),
                    ],
                  ),
                ),
                (edgeText != null)
                    ? Text(edgeText!,
                        style: TextStyle(
                            fontSize: 14, color: context.theme.textSecondary))
                    : Container(),
                const SizedBox(width: 4),
                widgetRight ?? Container(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// @override
// Widget build(BuildContext context) {
//   return Container(
//     color: context.theme.panelBackground,
//     child: Padding(
//       padding: const EdgeInsets.all(14.0),
//       child: Container(
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(10),
//         ),
//         child: Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10.0),
//           child: Row(
//             children: [
//               Container(
//                 alignment: Alignment.center,
//                 decoration: BoxDecoration(
//                   color: Colors.grey.shade500,
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: Padding(
//                   padding: const EdgeInsets.all(4.0),
//                   child: Icon(
//                     Icons.settings,
//                     color: Colors.white,
//                   ),
//                 ),
//               ),
//               SizedBox(width: 14),
//               Text("General",
//                   style:
//                   TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
//               Spacer(),
//               Icon(
//                 CupertinoIcons.chevron_forward,
//                 color: Colors.grey.shade400,
//               ),
//             ],
//           ),
//         ),
//       ),
//     ),
//   );
// }
