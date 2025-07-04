import 'package:common/common/module/modal/modal.dart';
import 'package:common/common/module/payment/payment.dart';
import 'package:common/common/widget/minicard/minicard.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/core/core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class WeeklyRefreshSheetIos extends StatefulWidget {
  const WeeklyRefreshSheetIos({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => WeeklyRefreshSheetIosState();
}

class WeeklyRefreshSheetIosState extends State<WeeklyRefreshSheetIos> {
  final _payment = Core.get<PaymentActor>();
  final _modal = Core.get<CurrentModalValue>();

  bool updating = false;
  bool updated = false;

  _updateFilters() async {
    setState(() {
      updating = true;
      updated = false;
    });

    try {
      await sleepAsync(const Duration(seconds: 5));
      if (mounted) {
        setState(() {
          updating = false;
          updated = true;
        });
      }
      await sleepAsync(const Duration(seconds: 1));
      if (mounted) {
        // Auto-close the modal after successful update
        Navigator.of(context).pop();
      }
    } catch (e) {
      // Handle any errors that may occur during the update process
      if (mounted) {
        setState(() {
          updating = false;
          updated = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: context.theme.bgColorCard,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      Text(
                        "Update your filters",
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium!
                            .copyWith(fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: Text(
                          "It's been a while since you updated your ad-block filters. Fetch them now to ensure you have the latest rules and improvements.",
                          softWrap: true,
                          textAlign: TextAlign.start,
                          style: TextStyle(color: context.theme.textSecondary, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Icon(
                  updated
                      ? CupertinoIcons.checkmark_shield
                      : (updating ? CupertinoIcons.shield : CupertinoIcons.exclamationmark_shield),
                  color: context.theme.bgColorHome2,
                  size: 80,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                updated
                    ? "Filters updated successfully"
                    : (updating ? "Updating filters..." : "Ready for an update"),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 160),
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: MiniCard(
                        onTap: _updateFilters,
                        color: context.theme.bgColor,
                        child: SizedBox(
                          height: 32,
                          child: Center(
                            child: Text(
                              "Update now",
                              style: TextStyle(
                                color: context.theme.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: MiniCard(
                        onTap: () async {
                          _modal.change(Markers.userTap, null);
                          _payment.openPaymentScreen(Markers.userTap,
                              placement: Placement.freemiumWeekly);
                        },
                        color: context.theme.accent,
                        child: const SizedBox(
                          height: 32,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                CupertinoIcons.heart_fill,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 12),
                              Center(
                                child: Text(
                                  "Upgrade for automatic updates",
                                  style:
                                      TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
