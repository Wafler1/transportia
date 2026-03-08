import 'package:flutter/foundation.dart';
import 'providers/backend_provider.dart';
import 'utils/app_version.dart';

class Environment {
  const Environment._();

  static const String appName = 'Transportia';
  static const String contactEmail = 'contact@wafler.one';
  static const String contactUrl = 'https://wafler.one';
  static const String privacyUrl = 'https://wafler.one/transportia/privacy';
  static const String termsUrl = 'https://wafler.one/transportia/terms';
  static const String downloadUrl = 'https://wafler.one/transportia/download';
  static const String sponsorUrl = 'http://wafler.one?ref=transportia';

  static const bool showBackendSettings = true;

  static String get transitousHost =>
      BackendProvider.instance?.host ?? BackendProvider.defaultHost;

  static String get _mainApiVersion =>
      BackendProvider.instance?.apiVersion ??
      (transitousHost.contains('transitous') ? 'v5' : 'v1');

  static String get planApiVersion =>
      BackendProvider.instance?.planVersion ?? _mainApiVersion;

  static String get tripApiVersion =>
      BackendProvider.instance?.tripVersion ?? _mainApiVersion;

  static String get stopTimesApiVersion =>
      BackendProvider.instance?.stopTimesVersion ?? _mainApiVersion;

  static String get mapTripsApiVersion =>
      BackendProvider.instance?.mapTripsVersion ?? _mainApiVersion;

  static String get mapStopsApiVersion =>
      BackendProvider.instance?.mapStopsVersion ?? 'v1';

  // Geocode always defaults to v1, independent of the main version.
  static String get geocodeApiVersion =>
      BackendProvider.instance?.geocodeVersion ?? 'v1';

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
