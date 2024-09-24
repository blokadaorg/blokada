import 'dart:convert';

import 'package:common/account/account.dart';
import 'package:common/account/json.dart';
import 'package:common/account/payment/channel.pg.dart';
import 'package:common/account/payment/json.dart';
import 'package:common/account/payment/payment.dart';
import 'package:common/stage/stage.dart';
import 'package:common/util/di.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../tools.dart';
import '../fixtures.dart';
@GenerateNiceMocks([
  MockSpec<AccountPaymentOps>(),
  MockSpec<AccountPaymentJson>(),
  MockSpec<AccountStore>(),
  MockSpec<AccountPaymentStore>(),
  MockSpec<StageStore>(),
])
import 'payment_test.mocks.dart';

final _fixtureProducts = [
  Product(
    id: "id1",
    title: "title1",
    description: "description1",
    price: "9.99",
    pricePerMonth: "9.99",
    periodMonths: 1,
    type: "plus",
    trial: null,
    owned: false,
  ),
  Product(
    id: "id2",
    title: "title2",
    description: "description2",
    price: "29.99",
    pricePerMonth: "2.09",
    periodMonths: 12,
    type: "cloud",
    trial: null,
    owned: false,
  ),
];

void main() {
  group("store", () {
    test("willFetchProducts", () async {
      await withTrace((trace) async {
        final ops = MockAccountPaymentOps();
        when(ops.doArePaymentsAvailable()).thenAnswer((_) async => true);
        when(ops.doFetchProducts()).thenAnswer((_) async => _fixtureProducts);
        depend<AccountPaymentOps>(ops);

        final subject = AccountPaymentStore();
        expect(subject.status, PaymentStatus.unknown);

        await subject.fetchProducts(trace);
        expect(subject.status, PaymentStatus.ready);
        expect(subject.products?.length, _fixtureProducts.length);
        expect(subject.products?[0].id, "id1");
        verify(ops.doFetchProducts()).called(1);
        verify(ops.doArePaymentsAvailable()).called(1);

        // Second call doesn't check availability again
        await subject.fetchProducts(trace);
        verify(ops.doFetchProducts()).called(1);
        verifyNever(ops.doArePaymentsAvailable());
      });
    });

    test("willPerformPurchase", () async {
      await withTrace((trace) async {
        depend<StageStore>(MockStageStore());

        final ops = MockAccountPaymentOps();
        when(ops.doArePaymentsAvailable()).thenAnswer((_) async => true);
        when(ops.doPurchaseWithReceipts(any))
            .thenAnswer((_) async => ["receipt"]);
        depend<AccountPaymentOps>(ops);

        final json = MockAccountPaymentJson();
        when(json.postCheckout(any, any, any)).thenAnswer(
            (_) async => JsonAccount.fromJson(jsonDecode(fixtureJsonAccount)));
        depend<AccountPaymentJson>(json);

        final account = MockAccountStore();
        depend<AccountStore>(account);

        final subject = AccountPaymentStore();
        mockAct(subject);

        await subject.purchase(trace, "id1");
        expect(subject.status, PaymentStatus.ready);
        verify(ops.doPurchaseWithReceipts("id1")).called(1);
        verify(json.postCheckout(any, "receipt", any)).called(1);
        verify(account.propose(any, any)).called(1);
      });
    });

    test("willProcessQueuedReceiptsFirstOnPurchase", () async {
      await withTrace((trace) async {
        final ops = MockAccountPaymentOps();
        when(ops.doArePaymentsAvailable()).thenAnswer((_) async => true);
        depend<AccountPaymentOps>(ops);

        final json = MockAccountPaymentJson();
        when(json.postCheckout(any, any, any)).thenAnswer(
            (_) async => JsonAccount.fromJson(jsonDecode(fixtureJsonAccount)));
        depend<AccountPaymentJson>(json);

        final account = MockAccountStore();
        depend<AccountStore>(account);

        final subject = AccountPaymentStore();
        mockAct(subject);
        subject.receipts = ["receipt1", "receipt2"];

        // Will try old receipts from the latest first and succeed without purchase
        await subject.purchase(trace, "id1");
        expect(subject.status, PaymentStatus.ready);
        expect(subject.receipts.isEmpty, true);
        verify(json.postCheckout(any, "receipt2", any)).called(1);
        verify(account.propose(any, any)).called(1);
        verifyNever(ops.doPurchaseWithReceipts(any));
      });
    });

    test("willRestore", () async {
      await withTrace((trace) async {
        final ops = MockAccountPaymentOps();
        when(ops.doArePaymentsAvailable()).thenAnswer((_) async => true);
        when(ops.doRestoreWithReceipts()).thenAnswer((_) async => ["receipt"]);
        depend<AccountPaymentOps>(ops);

        final json = MockAccountPaymentJson();
        when(json.postCheckout(any, any, any)).thenAnswer(
            (_) async => JsonAccount.fromJson(jsonDecode(fixtureJsonAccount)));
        depend<AccountPaymentJson>(json);

        final account = MockAccountStore();
        depend<AccountStore>(account);

        final subject = AccountPaymentStore();
        mockAct(subject);
        expect(subject.status, PaymentStatus.unknown);

        await subject.restore(trace);
        expect(subject.status, PaymentStatus.ready);
        verify(ops.doRestoreWithReceipts()).called(1);
        verify(json.postCheckout(any, "receipt", any)).called(1);
        verify(account.propose(any, any)).called(1);
      });
    });

    test("willRestoreInBackground", () async {
      await withTrace((trace) async {
        final ops = MockAccountPaymentOps();
        when(ops.doArePaymentsAvailable()).thenAnswer((_) async => true);
        depend<AccountPaymentOps>(ops);

        final json = MockAccountPaymentJson();
        when(json.postCheckout(any, "good receipt", any)).thenAnswer(
            (_) async => JsonAccount.fromJson(jsonDecode(fixtureJsonAccount)));
        when(json.postCheckout(any, "bad receipt", any))
            .thenThrow(Exception("bad receipt"));
        depend<AccountPaymentJson>(json);

        final account = MockAccountStore();
        depend<AccountStore>(account);

        final subject = AccountPaymentStore();
        mockAct(subject);
        subject.receipts = ["old receipt", "good receipt"];
        expect(subject.status, PaymentStatus.unknown);

        // Will try the "bad receipt" provided first, then the "good receipt"
        // from the old queued up receipts, and ignore the "old receipt".
        await subject.restoreInBackground(trace, "bad receipt");

        expect(subject.status, PaymentStatus.ready);
        expect(subject.receipts.isEmpty, true);
        verify(json.postCheckout(any, "bad receipt", any)).called(1);
        verify(json.postCheckout(any, "good receipt", any)).called(1);
        verify(account.propose(any, any)).called(1);
      });
    });
  });

  group("storeErrors", () {
    test("willNotFetchProductsIfNotReady", () async {
      await withTrace((trace) async {
        depend<StageStore>(MockStageStore());

        final ops = MockAccountPaymentOps();
        when(ops.doArePaymentsAvailable()).thenAnswer((_) async => false);
        depend<AccountPaymentOps>(ops);

        final subject = AccountPaymentStore();

        await expectLater(subject.fetchProducts(trace), throwsException);
        expect(subject.status, PaymentStatus.fatal);
        expect(subject.products, null);
        verify(ops.doArePaymentsAvailable()).called(1);
        verifyNever(ops.doFetchProducts());
      });
    });

    test("willNotCallApiOnFailingPurchase", () async {
      await withTrace((trace) async {
        depend<StageStore>(MockStageStore());

        final ops = MockAccountPaymentOps();
        when(ops.doArePaymentsAvailable()).thenAnswer((_) async => true);
        when(ops.doPurchaseWithReceipts(any))
            .thenThrow(Exception("Channel failing"));
        depend<AccountPaymentOps>(ops);

        final json = MockAccountPaymentJson();
        depend<AccountPaymentJson>(json);

        final account = MockAccountStore();
        depend<AccountStore>(account);

        final subject = AccountPaymentStore();

        await expectLater(subject.purchase(trace, "id1"), throwsException);
        expect(subject.status, PaymentStatus.ready);
        verify(ops.doPurchaseWithReceipts("id1")).called(1);
        verifyNever(json.postCheckout(any, any, any));
        verifyNever(account.propose(any, any));
      });
    });

    test("willNotProposeAccountOnFailingApiCall", () async {
      await withTrace((trace) async {
        depend<StageStore>(MockStageStore());

        final ops = MockAccountPaymentOps();
        when(ops.doArePaymentsAvailable()).thenAnswer((_) async => true);
        when(ops.doPurchaseWithReceipts(any))
            .thenAnswer((_) async => ["receipt"]);
        depend<AccountPaymentOps>(ops);

        final json = MockAccountPaymentJson();
        when(json.postCheckout(any, any, any))
            .thenThrow(Exception("Api failing"));
        depend<AccountPaymentJson>(json);

        final account = MockAccountStore();
        depend<AccountStore>(account);

        final subject = AccountPaymentStore();
        mockAct(subject);

        await expectLater(subject.purchase(trace, "id1"), throwsException);
        expect(subject.status, PaymentStatus.ready);
        verify(ops.doPurchaseWithReceipts("id1")).called(1);
        verify(json.postCheckout(any, "receipt", any)).called(1);
        verifyNever(account.propose(any, any));
      });
    });

    test("willNotProposeAccountOnApiReturningInactiveAccount", () async {
      await withTrace((trace) async {
        depend<StageStore>(MockStageStore());

        final ops = MockAccountPaymentOps();
        when(ops.doArePaymentsAvailable()).thenAnswer((_) async => true);
        when(ops.doPurchaseWithReceipts(any))
            .thenAnswer((_) async => ["receipt"]);
        depend<AccountPaymentOps>(ops);

        final json = MockAccountPaymentJson();
        when(json.postCheckout(any, any, any)).thenAnswer(
            (_) async => JsonAccount.fromJson(jsonDecode(fixtureJsonAccount2)));
        depend<AccountPaymentJson>(json);

        final account = MockAccountStore();
        depend<AccountStore>(account);

        final subject = AccountPaymentStore();
        mockAct(subject);

        await expectLater(subject.purchase(trace, "id1"), throwsException);
        expect(subject.status, PaymentStatus.ready);
        verify(ops.doPurchaseWithReceipts("id1")).called(1);
        verify(json.postCheckout(any, "receipt", any)).called(1);
        verifyNever(account.propose(any, any));
      });
    });
  });

  group("binder", () {
    test("onStatusChanged", () async {
      await withTrace((trace) async {
        final ops = MockAccountPaymentOps();
        when(ops.doArePaymentsAvailable()).thenAnswer((_) async => true);
        depend<AccountPaymentOps>(ops);

        final store = AccountPaymentStore();
        depend<AccountPaymentStore>(store);

        await store.fetchProducts(trace);
        verify(ops.doPaymentStatusChanged(PaymentStatus.fetching)).called(1);
        verify(ops.doPaymentStatusChanged(PaymentStatus.ready)).called(1);
      });
    });
  });
}
