var jsonUrl = "https://api.blocka.net";

class JsonError extends Error {
  final Map<String, dynamic> json;
  final Error error;

  JsonError(this.json, this.error);

  @override
  String toString() {
    return "JsonError: $error, json: $json";
  }
}
