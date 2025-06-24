import 'package:common/common/module/api/api.dart';
import 'package:common/common/module/onboard/onboard.dart';
import 'package:common/core/core.dart';
import 'package:common/platform/account/account.dart';
import 'package:common/platform/app/app.dart';
import 'package:common/util/mobx.dart';

part 'safari_content_actor.dart';
part 'value.dart';

class BlockaWebModule with Module {
  @override
  onCreateModule() async {
    await register(BlockawebAppStatusValue());
    await register(BlockawebPingValue());
    await register(BlockaWebActor());
    await register(SafariContentActor());
  }
}

class BlockaWebActor with Actor, Logging {
  late final _scheduler = Core.get<Scheduler>();
  late final _app = Core.get<AppStore>();
  late final _account = Core.get<AccountEphemeral>();
  late final _onboardSafari = Core.get<OnboardSafariValue>();

  late final _appStatus = Core.get<BlockawebAppStatusValue>();
  late final _ping = Core.get<BlockawebPingValue>();

  DateTime _accountActiveUntil = DateTime(0);
  bool _appActive = false;
  bool _freemium = false;
  DateTime? _freemiumYoutubeUntil;

  @override
  onStart(Marker m) async {
    await _appStatus.fetch(m);

    reactionOnStore((_) => _app.status, (retention) async {
      _appActive = _app.status.isActive();
      await _scheduleSync(m);
    });

    _account.onChangeInstant(_updateStatusFromAccount);
  }

  Future<bool> needsOnboard(Marker m) async {
    final ping = await _ping.fetch(m);
    final userSkipped = await _onboardSafari.now();

    // Uer skipped onboarding, leave them alone
    if (userSkipped) return false;

    // Fresh onboarding case, show onboard
    if (ping == null) return true;

    // // Extension seen long ago, show onboard
    // final oneDayAgo = DateTime.now().subtract(const Duration(minutes: 5));
    // if (ping.timestamp.isBefore(oneDayAgo)) {
    //   return true;
    // }

    // Extension seen recently, no need to onboard
    return false;
  }

  _updateStatusFromAccount(ValueUpdate<AccountState> it) async {
    _accountActiveUntil = DateTime.tryParse(it.now.jsonAccount.activeUntil ?? "") ?? DateTime(0);

    // Extract freemium attributes from account
    final attributes = it.now.jsonAccount.attributes ?? {};
    _freemium = attributes['freemium'] as bool? ?? false;

    if (attributes['freemium_youtube_until'] != null) {
      _freemiumYoutubeUntil = DateTime.tryParse(attributes['freemium_youtube_until'] as String);
    } else {
      _freemiumYoutubeUntil = null;
    }

    await _scheduleSync(it.m);
  }

  _scheduleSync(Marker m) async {
    await _scheduler.addOrUpdate(Job(
      "blockaweb:sync",
      m,
      before: DateTime.now(),
      callback: _syncBlockaweb,
    ));
  }

  Future<bool> _syncBlockaweb(Marker m) async {
    final newStatus = JsonBlockaweb(
      timestamp: _accountActiveUntil,
      active: _appActive,
      freemium: _freemium,
      freemiumYoutubeUntil: _freemiumYoutubeUntil,
    );

    await _appStatus.change(m, newStatus);
    await _ping.fetch(m, force: true);
    return false;
  }
}
