import '../../account/account.dart';
import '../../http/channel.pg.dart';
import '../../util/async.dart';
import '../../util/di.dart';
import 'api.dart';

final _account = dep<AccountStore>();

class ProdApiActor extends ApiActor {
  ProdApiActor(Act act, HttpRequest request)
      : super(
          actionHttp: (it) async {
            final ops = HttpOps();
            return await ops.doGet(it.url);
          },
          actionSleep: (it) async {
            final wait = act.isProd() ? 3 : 0;
            await sleepAsync(Duration(seconds: wait));
          },
        ) {
    final baseUrl = act.isFamily()
        ? "https://family.api.blocka.net/"
        : "https://api.blocka.net/";

    final params = {
      ApiParam.accountId: _account.id,
    };

    config(baseUrl, params);
  }
}
