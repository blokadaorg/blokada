import 'package:pigeon/pigeon.dart';

class PlusKeypair {
  late String publicKey;
  late String privateKey;
}

@HostApi()
abstract class PlusKeypairOps {
  @async
  PlusKeypair doGenerateKeypair();

  @async
  void doCurrentKeypair(PlusKeypair keypair);
}
