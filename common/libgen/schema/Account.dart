import 'package:pigeon/pigeon.dart';

class Account {
  final String id;
  final String? activeUntil;
  final bool? active;
  final String? type;
  final String? paymentSource;

  Account({
    required this.id,
    required this.activeUntil,
    required this.active,
    required this.type,
    required this.paymentSource,
  });
}

@HostApi()
abstract class AccountOps {
  @async
  void doAccountChanged(Account account);
}
