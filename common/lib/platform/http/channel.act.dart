import 'dart:convert';

import 'package:common/core/core.dart';
import 'package:dartx/dartx.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

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

    String t = type.toUpperCase();
    http.Response response;
    if (t == "POST") {
      response = await http.post(uri, headers: headers, body: payload);
    } else if (t == "PUT") {
      response = await http.put(uri, headers: headers, body: payload);
    } else if (t == "DELETE") {
      response = await http.delete(uri, headers: headers, body: payload);
    } else {
      throw Exception("Unsupported type: $t");
    }

    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw Exception("code:${response.statusCode}, body: ${response.body}");
    }
  }

  @override
  Future<String> doRequestWithHeaders(
      String url, String? payload, String type, Map<String?, String?> h) async {
    final uri = Uri.parse(url);
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    };
    headers.addAll(h
        .filter((map) => map.key != null && map.value != null)
        .map((key, value) => MapEntry(key!, value!)));

    String t = type.toUpperCase();
    http.Response response;
    if (t == "POST") {
      response = await http.post(uri, headers: headers, body: payload);
    } else if (t == "PUT") {
      response = await http.put(uri, headers: headers, body: payload);
    } else if (t == "DELETE") {
      response = await http.delete(uri, headers: headers, body: payload);
    } else {
      throw Exception("Unsupported type: $t");
    }

    if (response.statusCode == 200) {
      // Make sure utf is used
      return utf8.decode(response.bodyBytes);
    } else {
      throw Exception("code:${response.statusCode}, body: ${response.body}");
    }
  }
}
