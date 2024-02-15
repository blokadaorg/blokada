import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../widget.dart';

class GuestSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: context.theme.bgColorCard,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(children: [
            Row(
              children: [
                Expanded(child: Container()),
                Text("Cancel", style: TextStyle(color: context.theme.accent)),
              ],
            ),
            const SizedBox(height: 48),
            Text("Locked mode",
                style: Theme.of(context)
                    .textTheme
                    .displaySmall!
                    .copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 48),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                children: [
                  Text(
                      "If this device is shared with your child, activate Locked mode to prevent any changes to the Blokada settings until you disable it.",
                      textAlign: TextAlign.justify,
                      style: TextStyle(color: context.theme.textSecondary)),
                  const SizedBox(height: 48),
                  const ExplainItemWidget(
                    icon: CupertinoIcons.lock,
                    title: "PIN code",
                    description:
                        "Set the PIN code in the following step, and Blokada will automatically lock.",
                  ),
                  const SizedBox(height: 24),
                  const ExplainItemWidget(
                    icon: CupertinoIcons.lock_shield,
                    title: "Separate configuration",
                    description:
                        "Adjust your settings to enable stricter filtering when Blokada is in Locked mode.",
                  ),
                ],
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: MiniCard(
                      onTap: () => {},
                      color: context.theme.accent,
                      child: const SizedBox(
                        height: 32,
                        child: Center(
                          child: Text(
                            "Continue",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ]),
        ),
      ),
    );
  }
}
