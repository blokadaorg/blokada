import 'package:pigeon/pigeon.dart';

/// Used by Pigeon to generate the bindings to the platform code. Make sure to
/// also change HttpChannelSpec (and rerun Pigeon) if you change this one.
@HostApi()
abstract class HttpOps {
  @async
  String doGet(String url);

  @async
  String doRequest(String url, String? payload, String type);

  @async
  String doRequestWithHeaders(
      String url, String? payload, String type, Map<String?, String?> headers);
}
