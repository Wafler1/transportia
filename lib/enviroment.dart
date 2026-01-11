import 'package:flutter/foundation.dart';
import 'utils/app_version.dart';

class Environment {
  const Environment._();

  static const String appName = 'Transportia';
  static const String contactEmail = 'contact@wafler.one';
  static const String contactUrl = 'https://wafler.one';

  static const String transitousHost = 'api.transitous.org';

  static String get transitousUserAgent =>
      '$appName/${AppVersion.current} (+$contactUrl; $contactEmail)';

  static Map<String, String> transitousHeaders({bool acceptJson = true}) {
    final headers = <String, String>{};
    if (!kIsWeb) {
      headers['User-Agent'] = transitousUserAgent;
    }
    if (acceptJson) {
      headers['accept'] = 'application/json';
    }
    return headers;
  }
}
