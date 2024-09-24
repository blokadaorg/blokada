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
  int? trial;
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
  List<String> doPurchaseWithReceipts(String productId);

  @async
  List<String> doRestoreWithReceipts();

  @async
  String doChangeProductWithReceipt(String productId);

  @async
  void doFinishOngoingTransaction();

  @async
  void doPaymentStatusChanged(PaymentStatus status);

  @async
  void doProductsChanged(List<Product> products);
}
