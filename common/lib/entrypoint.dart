import 'dart:io';

import 'account/account.dart';
import 'account/channel.pg.dart';
import 'account/payment/channel.pg.dart';
import 'account/payment/payment.dart';
import 'account/refresh/refresh.dart';
import 'app/app.dart';
import 'app/channel.pg.dart';
import 'app/pause/channel.pg.dart';
import 'app/pause/pause.dart';
import 'custom/channel.pg.dart';
import 'custom/custom.dart';
import 'deck/channel.pg.dart';
import 'deck/deck.dart';
import 'device/channel.pg.dart';
import 'device/device.dart';
import 'env/env.dart';
import 'event.dart';
import 'http/http.dart';
import 'journal/channel.pg.dart';
import 'journal/journal.dart';
import 'notification/channel.pg.dart';
import 'notification/notification.dart';
import 'perm/perm.dart';
import 'persistence/persistence.dart';
import 'plus/channel.pg.dart';
import 'plus/gateway/channel.pg.dart';
import 'plus/gateway/gateway.dart';
import 'plus/keypair/channel.pg.dart';
import 'plus/keypair/keypair.dart';
import 'plus/lease/channel.pg.dart';
import 'plus/lease/lease.dart';
import 'plus/plus.dart';
import 'plus/vpn/channel.pg.dart';
import 'plus/vpn/vpn.dart';
import 'stage/stage.dart';
import 'stats/refresh/refresh.dart';
import 'stats/stats.dart';
import 'timer/timer.dart';
import 'ui/home/home.dart';
import 'util/config.dart';
import 'util/di.dart';
import 'util/trace.dart';
import 'stage/channel.pg.dart';
import 'util/tracer.dart';

class Entrypoint
    with
        TraceOrigin,
        Traceable,
        Dependable,
        EventBus,
        StageEvents,
        AccountEvents,
        AccountPaymentEvents,
        AppPauseEvents,
        CustomEvents,
        DeckEvents,
        DeviceEvents,
        JournalEvents,
        NotificationEvents,
        PlusEvents,
        PlusLeaseEvents,
        PlusVpnEvents {
  late final _stage = dep<StageStore>();
  late final _env = dep<EnvStore>();
  late final _account = dep<AccountStore>();
  late final _accountPayment = dep<AccountPaymentStore>();
  late final _accountRefresh = dep<AccountRefreshStore>();
  late final _app = dep<AppStore>();
  late final _appPause = dep<AppPauseStore>();
  late final _custom = dep<CustomStore>();
  late final _deck = dep<DeckStore>();
  late final _device = dep<DeviceStore>();
  late final _journal = dep<JournalStore>();
  late final _notification = dep<NotificationStore>();
  late final _perm = dep<PermStore>();
  late final _plus = dep<PlusStore>();
  late final _plusKeypair = dep<PlusKeypairStore>();
  late final _plusGateway = dep<PlusGatewayStore>();
  late final _plusLease = dep<PlusLeaseStore>();
  late final _plusVpn = dep<PlusVpnStore>();
  late final _statsRefresh = dep<StatsRefreshStore>();

  late Config cfg = Config();

  @override
  attach() {
    // Order is important
    depend<EventBus>(this);
    DefaultTracer().attach();
    DefaultTimer().attach();
    RepeatingHttpService(
      PlatformHttpService(),
      maxRetries: cfg.httpMaxRetries,
      waitTime: cfg.httpRetryDelay,
    ).attach();
    PlatformPersistence(isSecure: true, isBackup: true).attach();
    EnvStore().attach();
    StageStore().attach();
    AccountStore().attach();
    AccountPaymentStore().attach();
    AccountRefreshStore().attach();
    PermStore().attach();
    AppStore().attach();
    AppPauseStore().attach();
    CustomStore().attach();
    DeckStore().attach();
    DeviceStore().attach();
    JournalStore().attach();
    NotificationStore().attach();
    PlusStore().attach();
    PlusKeypairStore().attach();
    PlusGatewayStore().attach();
    PlusLeaseStore().attach();
    PlusVpnStore().attach();
    StatsStore().attach();
    StatsRefreshStore().attach();
    HomeStore().attach();

    StageEvents.setup(this);
    AccountEvents.setup(this);
    AccountPaymentEvents.setup(this);
    AppPauseEvents.setup(this);
    CustomEvents.setup(this);
    DeckEvents.setup(this);
    DeviceEvents.setup(this);
    JournalEvents.setup(this);
    NotificationEvents.setup(this);
    PlusEvents.setup(this);
    PlusLeaseEvents.setup(this);
    PlusVpnEvents.setup(this);
  }

  @override
  Future<void> onEvent(Trace trace, CommonEvent event) async {
    trace.addEvent(event.toString());
    switch (event) {
      case CommonEvent.stageForegroundChanged:
        final isForeground = _stage.isForeground;
        await _statsRefresh.updateForeground(trace, isForeground);
        if (isForeground) {
          await _accountRefresh.maybeRefresh(trace);
          await _plusGateway.fetch(trace); // TODO: too often
          await _plusLease.maybeRefreshLease(trace);
          await _perm.syncForeground(trace, isForeground);
        }
        break;
      case CommonEvent.stageRouteChanged:
        await _accountRefresh.maybeRefresh(trace);
        await _custom.maybeRefreshCustom(trace);
        await _deck.maybeRefreshDeck(trace);
        await _device.maybeRefreshDevice(trace);
        await _statsRefresh.updateScreen(trace,
            isHome: _stage.route.isTop(StageTab.home), isStats: false // TODO
            );
        break;
      case CommonEvent.stageModalChanged:
        if (_stage.modal == StageModal.plusLocationSelect) {
          await _plusGateway.fetch(trace);
        }
        break;
      case CommonEvent.appStatusChanged:
        await _stage.setReady(trace, !_app.status.isWorking());
        if (!_app.status.isWorking()) {
          //await _plus.reactToAppStatus(trace, _app.status.isActive());
        }
        break;
      case CommonEvent.accountChanged:
        final account = _account.account!;
        await _env.setAccountId(trace, account.id);
        await _app.accountUpdated(
          trace,
          isCloud: account.type == AccountType.cloud,
          isPlus: account.type == AccountType.plus,
        );
        await _device.maybeRefreshDevice(trace);
        await _statsRefresh.updateAccount(trace, account.type.isActive());
        break;
      case CommonEvent.accountTypeChanged:
        await _stage.showModalNow(trace, StageModal.onboarding);
        break;
      case CommonEvent.accountIdChanged:
        await _plusKeypair.generate(trace);
        await _device.maybeRefreshDevice(trace, force: true);
        break;
      case CommonEvent.plusKeypairChanged:
        await _plus.clearPlus(trace);
        break;
      case CommonEvent.deviceConfigChanged:
        final tag = _device.deviceTag!;
        final cloudEnabled = _device.cloudEnabled!;
        await _env.setDeviceTag(trace, tag);
        await _perm.syncDeviceTag(trace, tag);
        await _app.cloudEnabled(trace, cloudEnabled);
        await _deck.setUserLists(trace, _device.lists!);
        await _journal.enableRefresh(
            trace, _device.retention?.isEnabled() ?? false);
        break;
      case CommonEvent.plusLeaseChanged:
        // final l = _plusLease.currentLease;
        // final k = _plusKeypair.currentKeypair;
        // final g = _plusGateway.currentGateway;
        // final e = _plus.plusEnabled;
        // final s = _app.status;
        //
        // if (l != null && k != null && g != null && e && !s.isInactive()) {
        //   // VPN is active/enabled, sync the newest config
        //   await _plusVpn.setConfig(trace, _assembleConfig(k, g, l));
        // } else if (l == null && e) {
        //   // VPN is active/enabled but there is no lease, take it down
        //   await _plus.clearPlus(trace);
        // }
        break;
      default:
        break;
    }
  }

  VpnConfig _assembleConfig(PlusKeypair keypair, Gateway gateway, Lease lease) {
    return VpnConfig(
      devicePrivateKey: keypair.privateKey,
      deviceTag: _env.currentDeviceTag,
      gatewayPublicKey: gateway.publicKey,
      gatewayNiceName: gateway.niceName,
      gatewayIpv4: gateway.ipv4,
      gatewayIpv6: gateway.ipv6,
      gatewayPort: gateway.port.toString(),
      leaseVip4: lease.vip4,
      leaseVip6: lease.vip6,
    );
  }

  Future<void> onStartApp() async {
    await traceAs("onStartApp", (trace) async {
      await _app.initStarted(trace);
      try {
        await _env.syncDeviceName(trace);
        // Default to show journal only for the current device
        await _journal.updateFilter(trace, deviceName: _env.deviceName);
        await _plusKeypair.load(trace);
        await _plus.load(trace);
        await _startAppWithRetry(trace);
        await _app.initCompleted(trace);
      } catch (e) {
        await _stage.showModalNow(trace, StageModal.accountInitFailed);
        rethrow;
      }
    });
  }

  // Init the account with a retry loop. Can be called multiple times if failed.
  Future<void> _startAppWithRetry(Trace trace) async {
    bool success = false;
    int attempts = 3;
    while (!success && attempts-- > 0) {
      try {
        await _accountRefresh.init(trace);
        success = true;
      } on Exception catch (_) {
        trace.addEvent("init failed, retrying");
        sleep(cfg.appStartFailWait);
      }
    }

    if (!success) {
      return Future.error(Exception("Failed to init account"));
    }
  }

  @override
  Future<void> onRetryStartApp() async {
    await traceAs("onRetryStartApp", (trace) async {
      await _stage.dismissModal(trace);
      await _startAppWithRetry(trace);
      await _app.initCompleted(trace);
    }, fallback: (trace, e) async {
      await _stage.showModalNow(trace, StageModal.accountInitFailed);
      throw Exception("Failed to retry start app, displaying user modal");
    });
  }

  @override
  Future<void> onUnpauseApp() async {
    await traceAs("onUnpauseApp", (trace) async {
      await _appPause.unpauseApp(trace);
    });
  }

  @override
  Future<void> onPauseApp(bool isIndefinitely) async {
    await traceAs("onPauseApp", (trace) async {
      if (isIndefinitely) {
        await _appPause.pauseAppIndefinitely(trace);
      } else {
        await _appPause.pauseAppUntil(trace, cfg.appPauseDuration);
      }
    });
  }

  @override
  Future<void> onForeground(bool isForeground) async {
    await traceAs("onForeground", (trace) async {
      await _stage.setForeground(trace, isForeground);
    });
  }

  @override
  Future<void> onModalTriggered(String modal) async {
    await traceAs("onModalTriggered", (trace) async {
      await _stage.showModalNow(
          trace, StageModal.values.byName(modal.toLowerCase()));
    });
  }

  @override
  Future<void> onModalDismissedByPlatform() async {
    await traceAs("onModalDismissedByPlatform", (trace) async {
      await _stage.dismissModal(trace, byPlatform: true);
    });
  }

  @override
  Future<void> onModalDismissedByUser() async {
    await traceAs("onModalDismissedByUser", (trace) async {
      await _stage.dismissModal(trace, byPlatform: false);
    });
  }

  @override
  Future<void> onNavPathChanged(String path) async {
    await traceAs("onNavPathChanged", (trace) async {
      await _stage.setRoute(trace, path);
    });
  }

  @override
  Future<void> onReceipt(String receipt) async {
    await traceAs("onReceipt", (trace) async {
      await _accountPayment.restoreInBackground(trace, receipt);
      await _accountRefresh.syncAccount(trace, _account.account);
    });
  }

  @override
  Future<void> onFetchProducts() async {
    await traceAs("onFetchProducts", (trace) async {
      await _accountPayment.fetchProducts(trace);
    });
  }

  @override
  Future<void> onPurchase(String productId) async {
    await traceAs("onPurchase", (trace) async {
      await _accountPayment.purchase(trace, productId);
      await _accountRefresh.syncAccount(trace, _account.account);
    });
  }

  @override
  Future<void> onRestore() async {
    // TODO:
    // Only restore implicitly if current account is not active
    // TODO: finish ongoing transaction after any success or fail (stop procsesnig)
    await traceAs("onRestore", (trace) async {
      await _accountPayment.restore(trace);
    });
  }

  @override
  Future<void> onRestoreAccount(String accountId) async {
    await traceAs("onRestoreAccount", (trace) async {
      await _account.restore(trace, accountId);
      await _accountRefresh.syncAccount(trace, _account.account);
    }, fallback: (trace, e) async {
      trace.addEvent("restore failed, displaying user modal");
      await _stage.showModalNow(trace, StageModal.accountRestoreFailed);
      throw e;
    });
  }

  @override
  Future<void> onAllow(String domainName) async {
    await traceAs("onAllow", (trace) async {
      await _custom.allow(trace, domainName);
    });
  }

  @override
  Future<void> onDeny(String domainName) async {
    await traceAs("onDeny", (trace) async {
      await _custom.deny(trace, domainName);
    });
  }

  @override
  Future<void> onDelete(String domainName) async {
    await traceAs("onDelete", (trace) async {
      await _custom.delete(trace, domainName);
    });
  }

  // @override
  // Future<void> onStartListening() async {
  //   await traceAs("onStartListening", (trace) async {
  //     _ops.doCustomAllowedChanged(_store.allowed);
  //     _ops.doCustomDeniedChanged(_store.denied);
  //   });
  // }

  @override
  Future<void> onEnableDeck(String deckId, bool enable) async {
    await traceAs("onEnableDeck", (trace) async {
      await _deck.setEnableDeck(trace, deckId, enable);
    });
  }

  @override
  Future<void> onEnableList(String listId, bool enable) async {
    await traceAs("onEnableList", (trace) async {
      await _deck.setEnableList(trace, listId, enable);
    });
  }

  @override
  Future<void> onToggleListByTag(String deckId, String tag) async {
    await traceAs("onToggleListByTag", (trace) async {
      await _deck.toggleListByTag(trace, deckId, tag);
    });
  }

  @override
  Future<void> onEnableCloud(bool enable) async {
    await traceAs("onEnableCloud", (trace) async {
      await _device.setCloudEnabled(trace, enable);
    });
  }

  @override
  Future<void> onSetRetention(String retention) async {
    await traceAs("onSetRetention", (trace) async {
      await _device.setRetention(trace, retention);
    });
  }

  @override
  Future<void> onSearch(String query) async {
    await traceAs("onSearch", (trace) async {
      await _journal.updateFilter(trace, searchQuery: query);
    });
  }

  @override
  Future<void> onShowForDevice(String deviceName) async {
    await traceAs("onShowForDevice", (trace) async {
      await _journal.updateFilter(trace, deviceName: deviceName);
    });
  }

  @override
  Future<void> onShowOnly(bool showBlocked, bool showPassed) async {
    await traceAs("onShowOnly", (trace) async {
      await _journal.updateFilter(
        trace,
        showOnly: showBlocked && showPassed
            ? JournalFilterType.showAll
            : showBlocked
                ? JournalFilterType.showBlocked
                : JournalFilterType.showPassed,
      );
    });
  }

  @override
  Future<void> onSort(bool newestFirst) async {
    await traceAs("onSort", (trace) async {
      await _journal.updateFilter(trace, sortNewestFirst: newestFirst);
    });
  }

  @override
  Future<void> onLoadMoreHistoricEntries() async {
    await traceAs("onLoadMoreHistoricEntries", (trace) async {
      throw Exception("Loading historic entries not implemented");
    });
  }

  @override
  Future<void> onUserAction(String notificationId) async {
    await traceAs("onUserAction", (trace) async {
      await _notification.dismiss(
          trace, NotificationId.values.byName(notificationId));
    });
  }

  @override
  Future<void> onNewPlus(String gatewayPublicKey) async {
    await traceAs("onNewPlus", (trace) async {
      // _autostartHandled = true;
      await _plus.newPlus(trace, gatewayPublicKey);
    });
  }

  @override
  Future<void> onClearPlus() async {
    await traceAs("onClearPlus", (trace) async {
      await _plus.clearPlus(trace);
    });
  }

  @override
  Future<void> onSwitchPlus(bool active) async {
    await traceAs("onSwitchPlus", (trace) async {
      // _autostartHandled = true;
      await _plus.switchPlus(trace, active);
    });
  }

  @override
  Future<void> onNewLease(String gatewayPublicKey) async {
    await traceAs("onNewLease", (trace) async {
      await _plusLease.newLease(trace, gatewayPublicKey);
    });
  }

  @override
  Future<void> onDeleteLease(Lease lease) async {
    await traceAs("onDeleteLease", (trace) async {
      await _plusLease.deleteLease(trace, lease);
    });
  }

  @override
  Future<void> onVpnStatus(String status) async {
    await traceAs("onVpnStatus", (trace) async {
      await _plusVpn.setActualStatus(trace, status);
    });
  }
}
