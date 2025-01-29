import 'package:common/core/core.dart';
import 'package:common/platform/account/account.dart';

part 'actor.dart';

class Keypair {
  String publicKey;
  String privateKey;

  Keypair({
    required this.publicKey,
    required this.privateKey,
  });

  Keypair.fromJson(Map<String, dynamic> json)
      : publicKey = json['publicKey'],
        privateKey = json['privateKey'];

  Map<String, dynamic> toJson() => {
        'publicKey': publicKey,
        'privateKey': privateKey,
      };
}

@PlatformProvided()
mixin KeypairChannel {
  Future<Keypair> doGenerateKeypair();
}

class CurrentKeypairValue extends JsonPersistedValue<Keypair> {
  CurrentKeypairValue() : super("plus:keypair", secure: true);

  @override
  Keypair fromJson(dynamic json) => Keypair.fromJson(json);

  @override
  Map<String, dynamic> toJson(Keypair value) => value.toJson();
}

class KeypairModule with Module {
  @override
  onCreateModule() async {
    await register(CurrentKeypairValue());
    await register(KeypairActor());
  }
}
