import 'package:common/src/features/modal/domain/modal.dart';
import 'package:common/src/features/notification/domain/notification.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'package:common/src/app_variants/v6/widget/freemium/weekly_refresh_sheet.dart';

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
