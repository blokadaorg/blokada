import 'package:pigeon/pigeon.dart';

enum PaymentStatus {
  unknown,
  fetching,
  ready,
  purchasing,
  restoring,
  fatal,
}

class Product {
  String id;
  String title;
  String description;
  String price;
  String pricePerMonth;
  int periodMonths;
  String type;
  bool trial;
  bool owned;

  Product(
    this.id,
    this.title,
    this.description,
    this.price,
    this.pricePerMonth,
    this.periodMonths,
    this.type,
    this.trial,
    this.owned,
  );
}

@HostApi()
abstract class AccountPaymentOps {
  @async
  bool doArePaymentsAvailable();

  @async
  List<Product> doFetchProducts();

  @async
  String doPurchaseWithReceipt(String productId);

  @async
  String doRestoreWithReceipt();

  @async
  String doChangeProductWithReceipt(String productId);

  @async
  void doFinishOngoingTransaction();

  @async
  void doPaymentStatusChanged(PaymentStatus status);

  @async
  void doProductsChanged(List<Product> products);
}
