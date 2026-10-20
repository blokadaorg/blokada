part of 'plan.dart';

/// Outcome of "Restore purchases" in Settings, for the screen to react to.
enum PlanRestoreOutcome {
  /// A purchase was found and handed to checkout, which reports its own result.
  restored,

  /// Nothing active to restore: the screen shows the #395 message.
  notFound,

  /// The store failed; the restore-failed sheet was already shown.
  failed,
}

/// Backs Settings "Your plan" (#454): the plain status, and the manage,
/// upgrade and restore actions. It only reads the store's subscription state
/// and reuses the paywall's checkout and placements, so purchase flows are
/// unchanged.
class PlanActor with Logging, Actor {
  late final _account = Core.get<AccountStore>();
  late final _channel = Core.get<PaymentChannel>();
  late final _payment = Core.get<PaymentActor>();
  late final _stage = Core.get<StageStore>();
  late final _plan = Core.get<CurrentPlanValue>();

  /// Last access levels read from the store, reused when only the account
  /// changes so an account refresh does not call the store every time.
  List<StoreSubscription> _subscriptions = [];

  @override
  Future<void> onStart(Marker m) async {
    // TODO: change to new Value type once AccountStore moves off MobX
    _account.addOn(accountChanged, _recompute);
  }

  /// Re-reads the store's renewal state; called when Settings opens. Skips the
  /// store for inactive accounts, which have nothing to renew.
  Future<void> refresh(Marker m) async {
    return await log(m).trace("planRefresh", (m) async {
      if (_account.type.isActive()) {
        try {
          _subscriptions = await _channel.fetchActiveSubscriptions(m);
        } catch (e, s) {
          // The status falls back to the account's end date, which is still true.
          log(m).e(msg: "Failed reading store subscriptions", err: e, stack: s);
          _subscriptions = [];
        }
      } else {
        _subscriptions = [];
      }
      await _recompute(m);
    });
  }

  Future<void> _recompute(Marker m) async {
    final plan = resolvePlan(
      account: _account.account?.jsonAccount,
      subscriptions: _subscriptions,
      now: DateTime.now(),
    );
    log(m).pair("plan", plan);
    _plan.now = plan;
  }

  /// Opens the page that manages the plan in the store it was bought in.
  /// Changing plan also happens there; there is no in-app downgrade (#1, #37).
  Future<void> manage(Marker m) async {
    return await log(m).trace("planManage", (m) async {
      final link = manageLinkFor(_plan.now.store, Core.act.platform);
      if (link == null) throw Exception("No store to manage plan in");
      await _stage.openLink(link, m);
    });
  }

  /// Cloud → Plus through the existing upgrade placement.
  Future<void> upgrade(Marker m) async {
    await _payment.openPaymentScreen(m, placement: Placement.plusUpgrade);
  }

  /// Same path as the paywall's restore: an active access level goes through
  /// checkout as a restore (so its failure shows the restore-failed sheet), and
  /// none at all is reported back for the #395 message.
  Future<PlanRestoreOutcome> restorePurchases(Marker m) async {
    return await log(m).trace("planRestore", (m) async {
      final String? profileId;
      try {
        profileId = await _channel.restorePurchases(m);
      } catch (e, s) {
        await _payment.handleFailure(m, "Failed restore", e, s: s, restore: true);
        return PlanRestoreOutcome.failed;
      }

      if (profileId == null) return PlanRestoreOutcome.notFound;
      await _payment.checkoutSuccessfulPayment(profileId, restore: true);
      await refresh(m);
      return PlanRestoreOutcome.restored;
    });
  }
}
