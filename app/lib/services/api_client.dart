import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/bobst.dart';

/// Override at build/run time:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000  (Android emulator)
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8000',
);

class ApiClient {
  ApiClient({http.Client? client, this.baseUrl = apiBaseUrl})
    : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;

  Future<BobstStatus> fetchStatus() async {
    final response = await _client
        .get(Uri.parse('$baseUrl/api/status'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Failed to load status (${response.statusCode})');
    }
    return BobstStatus.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}
