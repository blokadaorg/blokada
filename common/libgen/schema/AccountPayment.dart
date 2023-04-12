import 'package:pigeon/pigeon.dart';

enum PaymentStatus { unknown, fetching, ready, purchasing, restoring, fatal }

class Product {
  String id;
  String title;
  String description;
  String price;
  int period;
  String type;
  bool trial;

  Product(this.id, this.title, this.description, this.price, this.period,
      this.type, this.trial);
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

@FlutterApi()
abstract class AccountPaymentEvents {
  @async
  void onReceipt(String receipt);

  @async
  void onFetchProducts();

  @async
  void onPurchase(String productId);

  @async
  void onRestore();
}
