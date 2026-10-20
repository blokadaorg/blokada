import 'package:common/src/core/core.dart';
import 'package:common/src/features/link/domain/link.dart';
import 'package:common/src/features/payment/domain/payment.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/platform/account/api.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'package:common/src/shared/ui/string.dart';
import 'package:dartx/dartx.dart';

part 'actor.dart';

/// Where a plan was bought, which decides where it is managed: the store's own
/// subscription page, or the web dashboard for web purchases (#204).
enum PlanStore { appStore, playStore, web, none }

/// What Settings can say about when the plan stops.
enum PlanRenewal {
  /// The store reports auto-renew on.
  renews,

  /// The store reports auto-renew off: cancelled, runs until the date.
  ends,

  /// Active, but no store tells us whether it renews (web or ticket sources,
  /// or the store could not be reached), so only the end date is known.
  activeUntil,

  /// Was paid before and has lapsed.
  expired,

  /// Never had a plan (including freemium).
  none,
}

/// The plain account status shown in Settings "Your plan" (#454).
class Plan {
  final AccountType type;
  final PlanRenewal renewal;
  final DateTime? date;
  final PlanStore store;

  const Plan({required this.type, required this.renewal, required this.date, required this.store});

  static const empty = Plan(
    type: AccountType.libre,
    renewal: PlanRenewal.none,
    date: null,
    store: PlanStore.none,
  );

  bool get isActive =>
      renewal == PlanRenewal.renews ||
      renewal == PlanRenewal.ends ||
      renewal == PlanRenewal.activeUntil;

  /// One tier naming across the app: "Blokada Cloud", "Blokada Plus".
  String get tierName => "Blokada ${type.name.firstLetterUppercase()}";

  @override
  bool operator ==(Object other) =>
      other is Plan &&
      other.type == type &&
      other.renewal == renewal &&
      other.date == date &&
      other.store == store;

  @override
  int get hashCode => Object.hash(type, renewal, date, store);

  @override
  String toString() => "Plan($type, $renewal, $date, $store)";
}

/// Maps the store of an Adapty access level, falling back to the backend's
/// payment source (api `ActivationSource`) when Adapty has no active level.
/// The access level wins: it names the store that actually bills the user,
/// which can differ from the platform the app runs on.
PlanStore resolvePlanStore({String? adaptyStore, String? paymentSource}) {
  switch (adaptyStore) {
    case "app_store":
      return PlanStore.appStore;
    case "play_store":
      return PlanStore.playStore;
    case "stripe":
      return PlanStore.web;
  }
  switch (paymentSource) {
    case "apple":
      return PlanStore.appStore;
    case "google":
      return PlanStore.playStore;
    case "stripe":
    case "paypal":
      return PlanStore.web;
  }
  // Tickets, internal grants and Adapty dashboard grants have nothing to manage.
  return PlanStore.none;
}

/// Combines the backend account with the store's access levels into the status
/// Settings shows. Pure, so the renews/ends/fallback rules are unit tested.
Plan resolvePlan({
  required JsonAccount? account,
  required List<StoreSubscription> subscriptions,
  required DateTime now,
}) {
  if (account == null) return Plan.empty;

  final type = accountTypeFromName(account.type);
  final activeUntil = account.activeUntil == null ? null : DateTime.tryParse(account.activeUntil!);

  if (!type.isActive()) {
    if (!account.hasBeenActiveBefore()) return Plan.empty;
    return Plan(
      type: type,
      renewal: PlanRenewal.expired,
      date: activeUntil,
      // Kept so a lapsed store subscription (billing issue) can still be fixed.
      store: resolvePlanStore(paymentSource: account.paymentSource),
    );
  }

  // Prefer the level matching the account tier (a Cloud → Plus upgrade can
  // briefly leave both active).
  final sub =
      subscriptions.firstOrNullWhere((it) => it.accessLevelId == type.name) ??
      subscriptions.firstOrNull;
  final store = resolvePlanStore(adaptyStore: sub?.store, paymentSource: account.paymentSource);

  final expiresAt = sub?.expiresAt;
  if (sub != null && expiresAt != null) {
    return Plan(
      type: type,
      renewal: sub.willRenew ? PlanRenewal.renews : PlanRenewal.ends,
      date: expiresAt,
      store: store,
    );
  }

  return Plan(type: type, renewal: PlanRenewal.activeUntil, date: activeUntil, store: store);
}

/// Where "Manage subscription" goes. The plan's own store, not the current
/// platform's: a plan bought on iPhone is managed in the App Store even when
/// viewed on Android. Null when there is nothing to manage.
LinkId? manageLinkFor(PlanStore store, PlatformType platform) {
  switch (store) {
    case PlanStore.appStore:
      return platform == PlatformType.iOS
          ? LinkId.manageSubscriptions
          : LinkId.manageSubscriptionsAppStore;
    case PlanStore.playStore:
      return platform == PlatformType.android
          ? LinkId.manageSubscriptions
          : LinkId.manageSubscriptionsPlayStore;
    case PlanStore.web:
      return LinkId.manageSubscriptionsWeb;
    case PlanStore.none:
      return null;
  }
}

/// The plan Settings shows; [PlanActor] keeps it current.
class CurrentPlanValue extends Value<Plan> {
  CurrentPlanValue() : super(load: () => Plan.empty);
}

class PlanModule with Module {
  @override
  onCreateModule() async {
    await register(CurrentPlanValue());
    await register(PlanActor());
  }
}
