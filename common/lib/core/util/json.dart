part of '../core.dart';

class JsonError extends Error {
  final Map<String, dynamic> json;
  final Error error;

  JsonError(this.json, this.error);

  @override
  String toString() {
    return "JsonError: $error, json: $json";
  }
}

typedef JsonString = String;
typedef Json = Map<String, dynamic>;

// @deprecated
var jsonUrl = "https://api.blocka.net";
