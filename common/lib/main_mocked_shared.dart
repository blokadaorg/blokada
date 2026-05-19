import 'package:common/src/core/core.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/platform/stage/stage.dart';

const _rawAccountId = String.fromEnvironment('ACCOUNT_ID');

// Manually trigger the foreground in mocked builds — the production startup
// path is gated on StartupPromotionGate which the mocked entries skip.
class MockedStart {
  late final StageStore _stage = Core.get<StageStore>();

  Future<void> start() async {
    await _stage.setForeground(Markers.start);
  }
}

// Seed an active dev account into secure storage so AccountStore finds one on
// startup and the paywall + first-account-create flow never runs. Real
// account.fetch() overwrites with truth on the next refresh tick. Reads the
// id from the compile-time ACCOUNT_ID dart-define — supplied either on the
// command line (`ACCOUNT_ID=xxx make run-{six,family}-mocked`) or via a
// gitignored repo-root .env.local file. See ios/SIMULATOR.md.
//
// Sanitization mirrors AccountStore._sanitizeAccountId (lowercase, trim,
// strip non-alphanumeric). The length check rejects obvious junk values
// like "xxx" or "test" that would otherwise persist and then trigger the
// refresh-tick 4xx → delete-and-create-throwaway-account path, which is
// the prod side effect this mechanism exists to prevent.
Future<void> seedDevAccount(Flavor flavor) async {
  final accountId = _rawAccountId
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[^a-z\d]'), '');
  if (accountId.length < 8) {
    throw StateError(
      _rawAccountId.isEmpty
          ? 'ACCOUNT_ID is not set. Pass on the command line '
              '(`ACCOUNT_ID=xxx make -C ios run-{six,family}-mocked`) or set '
              'SIX_DEV_ACCOUNT_ID / FAMILY_DEV_ACCOUNT_ID in '
              '<repo-root>/.env.local. See ios/SIMULATOR.md.'
          : 'ACCOUNT_ID is malformed: must be at least 8 lowercase '
              'alphanumeric characters after sanitization. See '
              'ios/SIMULATOR.md.',
    );
  }

  final isFamily = flavor == Flavor.family;
  final type = isFamily ? 'family' : 'cloud';

  final persistence = Core.get<Persistence>(tag: Persistence.secure);
  final existing = await persistence.load(Markers.start, keyAccount, isBackup: true);
  if (existing != null && existing.isNotEmpty) return;

  await persistence.saveJson(Markers.start, keyAccount, {
    'id': accountId,
    'active_until': '2099-01-01T00:00:00Z',
    'active': true,
    'type': type,
    'payment_source': 'mocked',
  }, isBackup: true);
}
