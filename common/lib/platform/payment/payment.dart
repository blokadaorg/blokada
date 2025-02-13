import 'package:common/core/core.dart';
import 'package:common/platform/payment/api.dart';
import 'package:common/util/mobx.dart';
import 'package:mobx/mobx.dart';

import '../account/account.dart';
import '../stage/channel.pg.dart';
import '../stage/stage.dart';
import 'channel.act.dart';
import 'channel.pg.dart';

part 'payment.g.dart';

typedef ProductId = String;
typedef ReceiptBlob = String;

class AccountPaymentStore = AccountPaymentStoreBase with _$AccountPaymentStore;

class AccountInactiveAfterPurchase implements Exception {}

class PaymentsUnavailable implements Exception {}

abstract class AccountPaymentStoreBase with Store, Logging, Actor {
  late final _ops = Core.get<PaymentOps>();
  late final _json = Core.get<AccountPaymentApi>();
  late final _account = Core.get<AccountStore>();
  late final _stage = Core.get<StageStore>();

  AccountPaymentStoreBase() {
    reactionOnStore((_) => status, (status) async {
      await _ops.doPaymentStatusChanged(status);
    });

    reactionOnStore((_) => products, (products) async {
      if (products != null) {
        await _ops.doProductsChanged(products);
      }
    });

    // TODO: remove this, only for payments upgrade / downgrade in UI
    reactionOnStore((_) => _account.account, (account) async {
      _ops.doAccountTypeChanged(account?.type.name ?? "libre");
    });
  }

  @override
  onRegister() {
    Core.register<PaymentOps>(getOps());
    Core.register<AccountPaymentApi>(AccountPaymentApi());
    Core.register<AccountPaymentStore>(this as AccountPaymentStore);
  }

  @observable
  PaymentStatus status = PaymentStatus.unknown;

  @observable
  List<Product>? products;

  @observable
  List<ReceiptBlob> receipts = [];

  @action
  Future<void> fetchProducts(Marker m) async {
    return await log(m).trace("fetchProducts", (m) async {
      try {
        await _ensureInit();
        _ensureReady();
        status = PaymentStatus.fetching;
        products = (await _ops.doFetchProducts()).cast<Product>();
        status = PaymentStatus.ready;
      } on PaymentsUnavailable catch (_) {
        await _stage.showModal(StageModal.paymentUnavailable, m);
        rethrow;
      } on Exception catch (_) {
        status = PaymentStatus.ready;
        await _stage.showModal(StageModal.paymentTempUnavailable, m);
        rethrow;
      } catch (_) {
        status = PaymentStatus.ready;
        await _stage.showModal(StageModal.paymentTempUnavailable, m);
        rethrow;
      }
    });
  }

  @action
  Future<void> purchase(ProductId id, Marker m) async {
    return await log(m).trace("purchase", (m) async {
      try {
        await _ensureInit();
        _ensureReady();

        status = PaymentStatus.purchasing;

        if (await _processQueuedReceipts(m)) {
          // Restored from a queued receipt, no need to purchase
          status = PaymentStatus.ready;
          return;
        }

        final receipts = await _ops.doPurchaseWithReceipts(id);
        await _processReceipt(
            receipts.first!, m); // Only one receipt expected in purchase flow
        //if (!Core.act.isFamily) await _stage.showModal(StageModal.perms, m);
        status = PaymentStatus.ready;
      } on Exception catch (e) {
        _ops.doFinishOngoingTransaction();
        status = PaymentStatus.ready;
        try {
          _mapPaymentException(e);
        } catch (_) {
          await _stage.showModal(StageModal.paymentFailed, m);
          rethrow;
        }
      } catch (_) {
        await _stage.showModal(StageModal.paymentFailed, m);
        _ops.doFinishOngoingTransaction();
        status = PaymentStatus.ready;
        rethrow;
      }
    });
  }

  @action
  Future<void> changeProduct(ProductId id, Marker m) async {
    return await log(m).trace("changeProduct", (m) async {
      try {
        await _ensureInit();
        _ensureReady();

        status = PaymentStatus.purchasing;

        // if (await _processQueuedReceipts) {
        //   // Restored from a queued receipt, no need to purchase
        //   status = PaymentStatus.ready;
        //   return;
        // }

        final receipt = await _ops.doChangeProductWithReceipt(id);
        await _processReceipt(receipt, m);
        status = PaymentStatus.ready;
        await _closePayments(m);
      } on Exception catch (e) {
        _ops.doFinishOngoingTransaction();
        status = PaymentStatus.ready;
        try {
          _mapPaymentException(e);
        } catch (_) {
          await _stage.showModal(StageModal.paymentFailed, m);
          rethrow;
        }
      } catch (_) {
        await _stage.showModal(StageModal.paymentFailed, m);
        _ops.doFinishOngoingTransaction();
        status = PaymentStatus.ready;
        rethrow;
      }
    });
  }

  @action
  Future<void> restore(Marker m) async {
    return await log(m).trace("restore", (m) async {
      try {
        await _ensureInit();
        _ensureReady();

        status = PaymentStatus.restoring;

        if (await _processQueuedReceipts(m)) {
          // Restored from a queued receipt, no need to purchase
          status = PaymentStatus.ready;
          return;
        }

        // Try each receipt until one is successful
        final receipts = await _ops.doRestoreWithReceipts();
        log(m).i("found ${receipts.length} receipts");

        bool success = false;
        for (final receipt in receipts) {
          try {
            await _processReceipt(receipt!, m);
            success = true;
            break;
          } catch (_) {}
        }
        if (!success) {
          throw AccountInactiveAfterPurchase();
        }
        status = PaymentStatus.ready;
      } on Exception catch (e) {
        _ops.doFinishOngoingTransaction();
        status = PaymentStatus.ready;
        try {
          _mapPaymentException(e);
        } on AccountInactiveAfterPurchase catch (_) {
          var modal = StageModal.accountRestoreFailed;
          //if (DI.act.isFamily) modal = StageModal.accountChange;

          await _stage.showModal(modal, m);
          rethrow;
        }
      } catch (_) {
        _ops.doFinishOngoingTransaction();
        status = PaymentStatus.ready;
        rethrow;
      }
    });
  }

  @action
  Future<void> restoreInBackground(ReceiptBlob receipt, Marker m) async {
    return await log(m).trace("restoreInBackground", (m) async {
      await _ensureInit();

      if (status != PaymentStatus.ready) {
        receipts.add(receipt);
        log(m).pair("queued", true);
        log(m).pair("queueSize", receipts.length);
        return;
      }

      status = PaymentStatus.restoring;
      try {
        await _processReceipt(receipt, m);

        // Succeeded (no exception), drop any older receipts
        receipts.clear();

        status = PaymentStatus.ready;
      } on Exception catch (e) {
        // Ignore any errors when processing payments in the background
        // Try any (older) queued receipts as a fallback
        await _processQueuedReceipts(m);
        status = PaymentStatus.ready;
      }
    });
  }

  _processReceipt(ReceiptBlob receipt, Marker m) async {
    final account = await _json.postCheckout(receipt, Core.act.platform, m);

    try {
      final type = AccountType.values.byName(account.type ?? "unknown");

      if (!type.isActive()) {
        throw AccountInactiveAfterPurchase();
      }

      log(m).log(
        msg: "restored active account",
        attr: {"accountId": account.id},
        sensitive: true,
      );
    } catch (e) {
      throw AccountInactiveAfterPurchase();
    }

    _ops.doFinishOngoingTransaction();
    await _account.propose(account, m);
  }

  Future<bool> _processQueuedReceipts(Marker m) async {
    if (receipts.isEmpty) {
      return false;
    }

    log(m).pair("queueSize", receipts.length);
    while (receipts.isNotEmpty) {
      // Process from the newest receipt first
      final receipt = receipts.removeLast();
      try {
        await log(m).trace("processQueuedReceipt", (m) async {
          await _processReceipt(receipt, m);
        });
        // Succeeded (no exception), drop any older receipts
        receipts.clear();
        return true;
      } on Exception catch (e) {
        // Ignore any errors when processing payments in the background
      }
    }
    return false;
  }

  _mapPaymentException(Exception e) {
    final msg = mapError(e);
    if (msg.contains("Payment sheet dismissed")) {
      // This is just ordinary StoreKit behavior, ignore
    } else if (msg
        .contains("Restoring purchase found no successful purchases")) {
      throw AccountInactiveAfterPurchase();
    } else {
      // Throw again to make sure it is traced
      throw e;
    }
  }

  _ensureInit() async {
    if (status == PaymentStatus.unknown &&
        !(await _ops.doArePaymentsAvailable())) {
      status = PaymentStatus.fatal;
      throw PaymentsUnavailable();
    } else if (status != PaymentStatus.fatal) {
      status = PaymentStatus.ready;
    }
  }

  _ensureReady() {
    if (status != PaymentStatus.ready) {
      throw Exception("Payments not ready");
    }
  }

  _closePayments(Marker m) async {
    if (_stage.route.modal == StageModal.payment) {
      await log(m).trace("dismissModalAfterAccountIdChange", (m) async {
        await _stage.dismissModal;
      });
    }
  }
}
