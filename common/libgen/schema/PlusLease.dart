import 'package:pigeon/pigeon.dart';

class Lease {
  late String accountId;
  late String publicKey;
  late String gatewayId;
  late String expires;
  late String? alias;
  late String vip4;
  late String vip6;
}

@HostApi()
abstract class PlusLeaseOps {
  @async
  void doLeasesChanged(List<Lease> leases);

  @async
  void doCurrentLeaseChanged(Lease? lease);
}
