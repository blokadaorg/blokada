import 'package:common/common/widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AvatarIconWidget extends StatelessWidget {
  final String? name;
  final Color? color;
  final IconData? icon;
  final bool big;

  const AvatarIconWidget(
      {super.key, this.name, this.color, this.icon, this.big = false})
      : assert(name != null || color != null);

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: ColorFiltered(
        colorFilter:
            ColorFilter.mode(color ?? genColor(name!), BlendMode.color),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.grey[600]!, Colors.grey[600]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SizedBox(
            width: big ? 120 : 60,
            height: big ? 120 : 60,
            child: Center(
                child: name != null
                    ? Text(
                        name!.substring(0, 2).toUpperCase(),
                        style: TextStyle(
                          fontSize: big ? 24 : 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        icon ?? CupertinoIcons.device_phone_portrait,
                        size: big ? 60 : 32,
                        color: Colors.white,
                      )),
          ),
        ),
      ),
    );
  }
}
