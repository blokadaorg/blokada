import '../../json/json.dart';

class AccountKeypair {
  late String publicKey;
  late String privateKey;

  AccountKeypair(this.publicKey, this.privateKey);

  AccountKeypair.fromJson(Map<String, dynamic> json) {
    try {
      publicKey = json['publicKey'];
      privateKey = json['privateKey'];
    } on TypeError catch (e) {
      throw JsonError(json, e);
    }
  }

  Map<String, dynamic> toJson() => {
    'publicKey': publicKey,
    'privateKey': privateKey,
  };
}

abstract class KeypairService {
  Future<AccountKeypair> generate();
}

void _ensureValidKeypair(AccountKeypair keypair) {
  if (keypair.publicKey.isEmpty) {
    throw Exception("Public key is empty");
  }
  if (keypair.privateKey.isEmpty) {
    throw Exception("Private key is empty");
  }
}

// final keypairJson = await _persistence.load(tLoad, _keyKeypair);
// if (keypairJson != null) {
// final keypair = AccountKeypair.fromJson(keypairJson);
// _ensureValidKeypair(keypair);
// account = Account(apiAccount.id, keypair, apiAccount);
// } else {
// final newKeypair = await _keypair.generate();
// account = Account(apiAccount.id, newKeypair, apiAccount);
// await _persistence.save(tLoad, _keyKeypair, newKeypair.toJson());
// tLoad.addEvent("generated new keypair");
// }

// static const String _keyKeypair = "account:keypair";
// late final _keypair = di<KeypairService>();


// // Regenerate keypair if account ID changed
// if (account == null || apiAccount.id != account?.id) {
// final keypair = await _keypair.generate();
// _ensureValidKeypair(keypair);
// account = Account(apiAccount.id, keypair, apiAccount);
// await _persistence.save(tPropose, _keyAccount, apiAccount.toJson());
// await _persistence.save(tPropose, _keyKeypair, keypair.toJson());
// tPropose.addEvent("generated new keypair");
// } else {
