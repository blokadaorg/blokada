import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;

import '../../util/di.dart';
import '../util/act.dart';
import 'channel.pg.dart';

class MockHttpOps extends Mock implements HttpOps {}

HttpOps getOps(Act act) {
  if (act.isProd()) {
    return HttpOps();
  }

  // final ops = MockHttpOps();
  // _actNormal(ops);
  // return ops;

  return DirectHttpOps();
}

class DirectHttpOps implements HttpOps {
  @override
  Future<String> doGet(String url) async {
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw Exception("code:${response.statusCode}, body: ${response.body}");
    }
  }

  @override
  Future<String> doRequest(String url, String? payload, String type) async {
    final uri = Uri.parse(url);
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
      // TODO: user agent?
    };

    http.Response response;
    if (type == "post") {
      response = await http.post(uri, headers: headers, body: payload);
    } else if (type == "put") {
      response = await http.put(uri, headers: headers, body: payload);
    } else if (type == "delete") {
      response = await http.delete(uri, headers: headers, body: payload);
    } else {
      throw Exception("Unsupported type: $type");
    }

    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw Exception("code:${response.statusCode}, body: ${response.body}");
    }
  }
}
