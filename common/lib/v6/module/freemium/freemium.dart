import 'package:common/common/module/modal/modal.dart';
import 'package:common/common/module/notification/notification.dart';
import 'package:common/core/core.dart';
import 'package:common/platform/account/account.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:common/v6/widget/freemium/weekly_refresh_sheet.dart';

part 'weekly_refresh.dart';

/// Currently this module is responsible for the weekly check and update of freemium lists
/// - Show notification if not opened for a week
/// - Show the sheet on open then
/// - Update lists / upgrade CTAs
/// - Only active for freemium user
class FreemiumModule with Module {
  @override
  onCreateModule() async {
    await register(WeeklyRefreshActor());
    await register(WeeklyLastOpenValue());
  }
}

class WeeklyLastOpenValue extends StringifiedPersistedValue<DateTime> {
  WeeklyLastOpenValue() : super('freemium:last_open');

  @override
  DateTime fromStringified(String value) => DateTime.parse(value);

  @override
  String toStringified(DateTime value) => value.toIso8601String();
}
