import 'package:common/tracer/collectors.dart';
import 'package:common/util/mobx.dart';
import 'package:mobx/mobx.dart';

import '../../stage/channel.pg.dart';
import '../../stage/stage.dart';
import '../../util/di.dart';
import '../../util/trace.dart';
import '../account.dart';
import 'channel.pg.dart';
import 'channel.act.dart';
import 'json.dart';

part 'payment.g.dart';

typedef ProductId = String;
typedef ReceiptBlob = String;

class AccountPaymentStore = AccountPaymentStoreBase with _$AccountPaymentStore;

class AccountInactiveAfterPurchase implements Exception {}

class PaymentsUnavailable implements Exception {}

abstract class AccountPaymentStoreBase with Store, Traceable, Dependable {
  late final _ops = dep<AccountPaymentOps>();
  late final _json = dep<AccountPaymentJson>();
  late final _account = dep<AccountStore>();
  late final _stage = dep<StageStore>();

  AccountPaymentStoreBase() {
    reactionOnStore((_) => status, (status) async {
      await _ops.doPaymentStatusChanged(status);
    });

    reactionOnStore((_) => products, (products) async {
      if (products != null) {
        await _ops.doProductsChanged(products);
      }
    });
  }

  @override
  attach(Act act) {
    depend<AccountPaymentOps>(getOps(act));
    depend<AccountPaymentJson>(AccountPaymentJson());
    depend<AccountPaymentStore>(this as AccountPaymentStore);
  }

  @observable
  PaymentStatus status = PaymentStatus.unknown;

  @observable
  List<Product>? products;

  @observable
  List<ReceiptBlob> receipts = [];

  @action
  Future<void> fetchProducts(Trace parentTrace) async {
    return await traceWith(parentTrace, "fetchProducts", (trace) async {
      try {
        await _ensureInit();
        _ensureReady();
        status = PaymentStatus.fetching;
        products = (await _ops.doFetchProducts()).cast<Product>();
        status = PaymentStatus.ready;
      } on PaymentsUnavailable catch (_) {
        await _stage.showModal(trace, StageModal.paymentUnavailable);
        rethrow;
      } on Exception catch (_) {
        status = PaymentStatus.ready;
        await _stage.showModal(trace, StageModal.paymentTempUnavailable);
        rethrow;
      } catch (_) {
        status = PaymentStatus.ready;
        await _stage.showModal(trace, StageModal.paymentTempUnavailable);
        rethrow;
      }
    });
  }

  @action
  Future<void> purchase(Trace parentTrace, ProductId id) async {
    return await traceWith(parentTrace, "purchase", (trace) async {
      try {
        await _ensureInit();
        _ensureReady();

        status = PaymentStatus.purchasing;

        if (await _processQueuedReceipts(trace)) {
          // Restored from a queued receipt, no need to purchase
          status = PaymentStatus.ready;
          return;
        }

        final receipt = await _ops.doPurchaseWithReceipt(id);
        await _processReceipt(trace, receipt);
        status = PaymentStatus.ready;
      } on Exception catch (e) {
        _ops.doFinishOngoingTransaction();
        status = PaymentStatus.ready;
        try {
          _mapPaymentException(e);
        } catch (_) {
          await _stage.showModal(trace, StageModal.paymentFailed);
          rethrow;
        }
      } catch (_) {
        await _stage.showModal(trace, StageModal.paymentFailed);
        _ops.doFinishOngoingTransaction();
        status = PaymentStatus.ready;
        rethrow;
      }
    });
  }

  @action
  Future<void> changeProduct(Trace parentTrace, ProductId id) async {
    return await traceWith(parentTrace, "changeProduct", (trace) async {
      try {
        await _ensureInit();
        _ensureReady();

        status = PaymentStatus.purchasing;

        // if (await _processQueuedReceipts(trace)) {
        //   // Restored from a queued receipt, no need to purchase
        //   status = PaymentStatus.ready;
        //   return;
        // }

        final receipt = await _ops.doChangeProductWithReceipt(id);
        await _processReceipt(trace, receipt);
        status = PaymentStatus.ready;
      } on Exception catch (e) {
        _ops.doFinishOngoingTransaction();
        status = PaymentStatus.ready;
        try {
          _mapPaymentException(e);
        } catch (_) {
          await _stage.showModal(trace, StageModal.paymentFailed);
          rethrow;
        }
      } catch (_) {
        await _stage.showModal(trace, StageModal.paymentFailed);
        _ops.doFinishOngoingTransaction();
        status = PaymentStatus.ready;
        rethrow;
      }
    });
  }

  @action
  Future<void> restore(Trace parentTrace) async {
    return await traceWith(parentTrace, "restore", (trace) async {
      try {
        await _ensureInit();
        _ensureReady();

        status = PaymentStatus.restoring;

        if (await _processQueuedReceipts(trace)) {
          // Restored from a queued receipt, no need to purchase
          status = PaymentStatus.ready;
          return;
        }

        final receipt = await _ops.doRestoreWithReceipt();
        await _processReceipt(trace, receipt);
        status = PaymentStatus.ready;
      } on Exception catch (e) {
        _ops.doFinishOngoingTransaction();
        status = PaymentStatus.ready;
        try {
          _mapPaymentException(e);
        } on AccountInactiveAfterPurchase catch (_) {
          await _stage.showModal(trace, StageModal.accountRestoreFailed);
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
  Future<void> restoreInBackground(
      Trace parentTrace, ReceiptBlob receipt) async {
    return await traceWith(parentTrace, "restoreInBackground", (trace) async {
      await _ensureInit();

      if (status != PaymentStatus.ready) {
        receipts.add(receipt);
        trace.addAttribute("queued", true);
        trace.addAttribute("queueSize", receipts.length);
        return;
      }

      status = PaymentStatus.restoring;
      try {
        await _processReceipt(trace, receipt);

        // Succeeded (no exception), drop any older receipts
        receipts.clear();

        status = PaymentStatus.ready;
      } on Exception catch (e) {
        // Ignore any errors when processing payments in the background
        // Try any (older) queued receipts as a fallback
        await _processQueuedReceipts(trace);
        status = PaymentStatus.ready;
      }
    });
  }

  _processReceipt(Trace trace, ReceiptBlob receipt) async {
    final account = await _json.postCheckout(trace, receipt);

    try {
      final type = AccountType.values.byName(account.type ?? "unknown");
      if (!type.isActive()) {
        throw AccountInactiveAfterPurchase();
      }
    } catch (e) {
      throw AccountInactiveAfterPurchase();
    }

    _ops.doFinishOngoingTransaction();
    await _account.propose(trace, account);
  }

  Future<bool> _processQueuedReceipts(Trace trace) async {
    if (receipts.isEmpty) {
      return false;
    }

    trace.addAttribute("queueSize", receipts.length);
    while (receipts.isNotEmpty) {
      // Process from the newest receipt first
      final receipt = receipts.removeLast();
      try {
        await traceWith(trace, "processQueuedReceipt", (trace) async {
          await _processReceipt(trace, receipt);
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
}
