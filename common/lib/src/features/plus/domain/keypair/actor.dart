part of 'keypair.dart';

class KeypairActor with Logging, Actor {
  late final _account = Core.get<AccountStore>();

  late final _channel = Core.get<KeypairChannel>();
  late final _currentKeypair = Core.get<CurrentKeypairValue>();

  // Satisfy notification module
  late final _publicKey = Core.get<PublicKeyProvidedValue>();

  @override
  onCreate(Marker m) async {
    _account.addOn(accountIdChanged, generate);

    await load(m);
  }

  load(Marker m) async {
    return await log(m).trace("load", (m) async {
      try {
        final keypair = await _currentKeypair.fetch(m);
        _ensureValidKeypair(keypair);
        await _publicKey.change(m, keypair!.publicKey);
      } on Exception catch (_) {
        await generate(m);
      }
    });
  }

  Future<void> generate(Marker m) async {
    return await log(m).trace("generate", (m) async {
      // throw Exception("test");
      final keypair = await _channel.doGenerateKeypair();
      _ensureValidKeypair(keypair);
      await _currentKeypair.change(m, keypair);
      await _publicKey.change(m, keypair.publicKey);
    });
  }

  _ensureValidKeypair(Keypair? keypair) {
    if (keypair == null) {
      throw Exception("Keypair is null");
    }
    if (keypair.publicKey.isEmpty) {
      throw Exception("Public key is empty");
    }
    if (keypair.privateKey.isEmpty) {
      throw Exception("Private key is empty");
    }
    if (keypair.publicKey == "pk-mocked") {
      throw Exception("Public key is mocked");
    }
    if (keypair.privateKey == "sk-mocked") {
      throw Exception("Private key is mocked");
    }
  }
}
