import 'package:common/src/features/modal/domain/modal.dart';
import 'package:common/src/features/payment/domain/payment.dart';
import 'package:common/src/shared/ui/minicard/minicard.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/core/core.dart';
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
                        "freemium refresh header".i18n,
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
                          "freemium refresh brief".i18n,
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
                    ? "freemium refresh status done".i18n
                    : (updating
                        ? "freemium refresh status updating".i18n
                        : "freemium refresh status ready".i18n),
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
                              "freemium refresh action update".i18n,
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
                        child: SizedBox(
                          height: 32,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                CupertinoIcons.heart_fill,
                                color: context.theme.onAccent,
                              ),
                              const SizedBox(width: 12),
                              Center(
                                child: Text(
                                  "freemium refresh action upgrade".i18n,
                                  style: TextStyle(
                                      color: context.theme.onAccent, fontWeight: FontWeight.w600),
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
