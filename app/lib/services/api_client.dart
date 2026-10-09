import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/bobst.dart';
import '../models/dev_settings.dart';
import '../models/rooms.dart';

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

  static const _timeout = Duration(seconds: 10);

  Future<BobstStatus> fetchStatus() async =>
      BobstStatus.fromJson(await _send('GET', '/api/status'));

  Future<List<RoomGroup>> fetchRooms() async {
    final body = await _send('GET', '/api/rooms');
    return (body['groups'] as List)
        .map((g) => RoomGroup.fromJson(g as Map<String, dynamic>))
        .toList();
  }

  Future<DevSettings> fetchDevSettings() async =>
      DevSettings.fromJson(await _send('GET', '/api/dev/settings'));

  Future<DevSettings> saveDevSettings(DevSettings settings) async =>
      DevSettings.fromJson(
        await _send('PUT', '/api/dev/settings', body: settings.toJson()),
      );

  Future<DevSettings> resetDevSettings() async =>
      DevSettings.fromJson(await _send('DELETE', '/api/dev/settings'));

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Object? body,
  }) async {
    final request = http.Request(method, Uri.parse('$baseUrl$path'));
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final response = await http.Response.fromStream(
      await _client.send(request).timeout(_timeout),
    );
    if (response.statusCode != 200) {
      throw Exception('$method $path failed (${response.statusCode})');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
