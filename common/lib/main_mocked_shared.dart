import 'package:common/dev_seed.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/platform/stage/stage.dart';

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
// id from common/lib/dev_seed.dart (gitignored, copied from the template
// once per checkout — see ios/SIMULATOR.md).
Future<void> seedDevAccount(Flavor flavor) async {
  final isFamily = flavor == Flavor.family;
  final id = isFamily ? familyDevAccountId : sixDevAccountId;
  final type = isFamily ? 'family' : 'cloud';
  final idName = isFamily ? 'familyDevAccountId' : 'sixDevAccountId';

  if (id.startsWith('REPLACE_')) {
    throw StateError(
      '$idName in common/lib/dev_seed.dart is unset. '
      'See ios/SIMULATOR.md for setup.',
    );
  }

  final persistence = Core.get<Persistence>(tag: Persistence.secure);
  final existing = await persistence.load(Markers.start, keyAccount, isBackup: true);
  if (existing != null && existing.isNotEmpty) return;

  await persistence.saveJson(Markers.start, keyAccount, {
    'id': id,
    'active_until': '2099-01-01T00:00:00Z',
    'active': true,
    'type': type,
    'payment_source': 'mocked',
  }, isBackup: true);
}
