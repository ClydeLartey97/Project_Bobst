import 'dart:convert';

import 'package:bobst/main.dart';
import 'package:bobst/services/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('shows floors returned by the API', (tester) async {
    final mock = MockClient((request) async {
      expect(request.url.path, '/api/floors');
      return http.Response(
        jsonEncode({
          'updated_at': '2026-10-08T15:00:00-04:00',
          'floors': [
            {
              'id': '5',
              'name': 'Floor 5',
              'occupancy': 180,
              'capacity': 220,
              'busyness': 0.818,
              'level': 'busy',
            },
          ],
        }),
        200,
      );
    });

    await tester.pumpWidget(BobstApp(api: ApiClient(client: mock)));
    await tester.pump();
    await tester.pump();

    expect(find.text('Floor 5'), findsOneWidget);
    expect(find.text('Busy'), findsOneWidget);
    expect(find.text('82% full'), findsOneWidget);
  });
}
