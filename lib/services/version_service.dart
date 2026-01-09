import 'dart:convert';

import 'package:http/http.dart' as http;

class VersionService {
  const VersionService._();

  static const String _endpoint = 'https://wafler.one/transportia/version';

  static Future<String?> fetchLatestVersion() async {
    try {
      final response = await http.get(Uri.parse(_endpoint));
      if (response.statusCode != 200) {
        return null;
      }
      final body = response.body;
      if (body.isEmpty) return null;

      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final version = decoded['version'];
        if (version is String && version.isNotEmpty) {
          return version;
        }
      }
    } catch (_) {
      // Silently swallow errors; update prompts shouldn't block startup.
    }
    return null;
  }
}
