import 'package:mocktail/mocktail.dart';

import '../../util/act.dart';
import '../../util/di.dart';
import 'channel.pg.dart';

class MockAccountPaymentOps extends Mock implements AccountPaymentOps {}

AccountPaymentOps getOps(Act act) {
  if (act.isProd()) {
    return AccountPaymentOps();
  }

  final ops = MockAccountPaymentOps();
  _actNormal(ops);
  return ops;
}

_actNormal(MockAccountPaymentOps ops) {
  registerFallbackValue(PaymentStatus.unknown);

  when(() => ops.doFinishOngoingTransaction()).thenAnswer(ignore());
  when(() => ops.doPaymentStatusChanged(any())).thenAnswer(ignore());
  when(() => ops.doProductsChanged(any())).thenAnswer(ignore());

  when(() => ops.doArePaymentsAvailable()).thenAnswer((_) async {
    return true;
  });

  when(() => ops.doFetchProducts()).thenAnswer((_) async {
    return [
      Product(
        id: 'id1',
        title: 'Product 1',
        description: 'Desc 1',
        price: '9.99',
        period: 1,
        type: 'cloud',
        trial: true,
      ),
    ];
  });

  when(() => ops.doPurchaseWithReceipt(any())).thenAnswer((_) async {
    return "mocked-receipt";
  });

  when(() => ops.doRestoreWithReceipt()).thenAnswer((_) async {
    return "mocked-receipt";
  });

  when(() => ops.doChangeProductWithReceipt(any())).thenAnswer((_) async {
    return "mocked-receipt";
  });
}
