import '../account/account.dart';
import '../account/payment/payment.dart';
import '../account/refresh/refresh.dart';
import '../app/start/start.dart';
import '../custom/custom.dart';
import '../deck/deck.dart';
import '../device/device.dart';
import '../journal/channel.pg.dart';
import '../journal/journal.dart';
import '../notification/notification.dart';
import '../plus/lease/lease.dart';
import '../plus/plus.dart';
import '../plus/vpn/vpn.dart';
import '../stage/channel.pg.dart';
import '../stage/stage.dart';
import '../timer/timer.dart';
import '../tracer/tracer.dart';
import '../util/config.dart';
import '../util/di.dart';
import '../util/trace.dart';
import 'channel.act.dart';
import 'channel.pg.dart';

class CommandStore with Traceable, Dependable, CommandEvents, TraceOrigin {
  late final _tracer = dep<Tracer>();
  late final _stage = dep<StageStore>();
  late final _account = dep<AccountStore>();
  late final _accountPayment = dep<AccountPaymentStore>();
  late final _accountRefresh = dep<AccountRefreshStore>();
  late final _appStart = dep<AppStartStore>();
  late final _custom = dep<CustomStore>();
  late final _deck = dep<DeckStore>();
  late final _device = dep<DeviceStore>();
  late final _journal = dep<JournalStore>();
  late final _plus = dep<PlusStore>();
  late final _plusLease = dep<PlusLeaseStore>();
  late final _plusVpn = dep<PlusVpnStore>();
  late final _notification = dep<NotificationStore>();

  late final _timer = dep<TimerService>();

  @override
  void attach(Act act) {
    depend<CommandStore>(this);
    if (act.isProd()) CommandEvents.setup(this);
    getOps(act).doCanAcceptCommands();
  }

  @override
  Future<void> onCommand(String command) async {
    final cmd = _commandFromString(command);
    _startCommandTimeout(cmd);
    await traceAs(_cmdName(command, null), (trace) async {
      return await execute(trace, cmd);
    });
    _stopCommandTimeout(cmd);
  }

  @override
  Future<void> onCommandWithParam(String command, String p1) async {
    final cmd = _commandFromString(command);
    _startCommandTimeout(cmd);
    await traceAs(_cmdName(command, p1), (trace) async {
      return await execute(trace, cmd, p1: p1);
    });
    _stopCommandTimeout(cmd);
  }

  @override
  Future<void> onCommandWithParams(String command, String p1, String p2) async {
    final cmd = _commandFromString(command);
    _startCommandTimeout(cmd);
    await traceAs(_cmdName(command, p1), (trace) async {
      return await execute(trace, cmd, p1: p1, p2: p2);
    });
    _stopCommandTimeout(cmd);
  }

  Future<void> onCommandString(Trace parentTrace, String command) async {
    return await traceWith(parentTrace, "onCommandString", (trace) async {
      final commandParts = command.split(" ");
      final cmd = _commandFromString(commandParts.first);
      final p1 = commandParts.elementAtOrNull(1);
      final p2 = commandParts.elementAtOrNull(2);
      return await execute(trace, cmd, p1: p1, p2: p2);
    });
  }

  execute(Trace trace, CommandName cmd, {String? p1, String? p2}) async {
    switch (cmd) {
      case CommandName.restore:
        await _account.restore(trace, p1!);
        return await _accountRefresh.syncAccount(trace, _account.account);
      case CommandName.receipt:
        await _accountPayment.restoreInBackground(trace, p1!);
        return await _accountRefresh.syncAccount(trace, _account.account);
      case CommandName.fetchProducts:
        return await _accountPayment.fetchProducts(trace);
      case CommandName.purchase:
        await _accountPayment.purchase(trace, p1!);
        return await _accountRefresh.syncAccount(trace, _account.account);
      case CommandName.changeProduct:
        await _accountPayment.changeProduct(trace, p1!);
        return await _accountRefresh.syncAccount(trace, _account.account);
      case CommandName.restorePayment:
        // TODO:
        // Only restore implicitly if current account is not active
        // TODO: finish ongoing transaction after any success or fail (stop processing)
        return await _accountPayment.restore(trace);
      case CommandName.pause:
        return await _appStart.pauseAppIndefinitely(trace);
      case CommandName.unpause:
        return await _appStart.unpauseApp(trace);
      case CommandName.allow:
        return await _custom.allow(trace, p1!);
      case CommandName.deny:
        return await _custom.deny(trace, p1!);
      case CommandName.delete:
        return await _custom.delete(trace, p1!);
      case CommandName.enableDeck:
        return await _deck.setEnableDeck(trace, p1!, true);
      case CommandName.disableDeck:
        return await _deck.setEnableDeck(trace, p1!, false);
      case CommandName.enableList:
        return await _deck.setEnableList(trace, p1!, true);
      case CommandName.disableList:
        return await _deck.setEnableList(trace, p1!, false);
      case CommandName.toggleListByTag:
        return await _deck.toggleListByTag(trace, p1!, p2!);
      case CommandName.enableCloud:
        return await _device.setCloudEnabled(trace, true);
      case CommandName.disableCloud:
        return await _device.setCloudEnabled(trace, false);
      case CommandName.setRetention:
        return await _device.setRetention(trace, p1!);
      case CommandName.sortNewest:
        return await _journal.updateFilter(trace, sortNewestFirst: true);
      case CommandName.sortCount:
        return await _journal.updateFilter(trace, sortNewestFirst: false);
      case CommandName.search:
        return await _journal.updateFilter(trace, searchQuery: p1);
      case CommandName.filter:
        return await _journal.updateFilter(trace,
            showOnly: JournalFilterType.values.byName(p1!));
      case CommandName.filterDevice:
        return await _journal.updateFilter(trace, deviceName: p1);
      case CommandName.newPlus:
        return await _plus.newPlus(trace, p1!);
      case CommandName.clearPlus:
        return await _plus.clearPlus(trace);
      case CommandName.activatePlus:
        return await _plus.switchPlus(trace, true);
      case CommandName.deactivatePlus:
        return await _plus.switchPlus(trace, false);
      case CommandName.deleteLease:
        return await _plusLease.deleteLeaseById(trace, p1!);
      case CommandName.vpnStatus:
        return await _plusVpn.setActualStatus(trace, p1!);
      case CommandName.foreground:
        return await _stage.setForeground(trace);
      case CommandName.background:
        return await _stage.setBackground(trace);
      case CommandName.route:
        return await _stage.setRoute(trace, p1!);
      case CommandName.modalShow:
        return await _stage.showModal(trace, _modalFromString(p1!));
      case CommandName.modalShown:
        return await _stage.modalShown(trace, _modalFromString(p1!));
      case CommandName.modalDismiss:
        return await _stage.dismissModal(trace);
      case CommandName.modalDismissed:
        return await _stage.modalDismissed(trace);
      case CommandName.remoteNotification:
        return await _accountRefresh.onRemoteNotification(trace);
      case CommandName.appleNotificationToken:
        return await _notification.saveAppleToken(trace, p1!);
      case CommandName.warning:
        return await _tracer.platformWarning(trace, p1!);
      case CommandName.fatal:
        return await _tracer.fatal(p1!);
      case CommandName.shareLog:
        return await _tracer.shareLog(trace, forCrash: false);
      case CommandName.debugHttpFail:
        cfg.debugFailingRequests.add(p1!);
        return;
      case CommandName.debugHttpOk:
        cfg.debugFailingRequests.remove(p1!);
        return;
    }
  }

  final _censoredCommands = [
    CommandName.restore.name,
    CommandName.receipt.name,
    CommandName.appleNotificationToken.name,
  ];

  final _noTimeLimitCommands = [
    CommandName.newPlus.name,
    CommandName.receipt.name,
    CommandName.restorePayment.name,
    CommandName.purchase.name,
  ];

  String _cmdName(String cmd, String? p1) {
    if (_censoredCommands.contains(cmd)) {
      p1 = "***";
    }
    return cmd + (p1 != null ? "(${shortString(p1, length: 16)})" : "()");
  }

  final Map<String, CommandName> _lowercaseCommandNames = {
    for (var cmd in CommandName.values) cmd.name.toLowerCase(): cmd,
  };

  CommandName _commandFromString(String command) {
    try {
      return CommandName.values.byName(command);
    } catch (_) {
      return _lowercaseCommandNames[command.toLowerCase()]!;
    }
  }

  final Map<String, StageModal> _lowercaseModals = {
    for (var cmd in StageModal.values) cmd.name.toLowerCase(): cmd,
  };

  StageModal _modalFromString(String command) {
    try {
      return StageModal.values.byName(command);
    } catch (_) {
      return _lowercaseModals[command.toLowerCase()]!;
    }
  }

  _onCommandTimer(String command) {
    try {
      _timer.addHandler("command:$command", (trace) async {
        // This will just show up in tracing
        throw Exception("Command '$command' is too slow");
      });
    } catch (e) {}
  }

  _startCommandTimeout(CommandName cmd) {
    final command = cmd.name;

    // These commands are just super slow because of StoreKit etc
    if (_noTimeLimitCommands.contains(command)) return;

    _onCommandTimer(command);
    _timer.set(
      "command:$command",
      DateTime.now().add(cfg.plusVpnCommandTimeout),
    );
  }

  _stopCommandTimeout(CommandName cmd) {
    final command = cmd.name;

    // This command is just super slow because of StoreKit
    if (command == "purchase") return;

    _timer.unset("command:$command");
  }
}
