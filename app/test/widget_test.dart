import 'dart:convert';

import 'package:bobst/main.dart';
import 'package:bobst/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

ApiClient fakeApi({required String status}) {
  final mock = MockClient((request) async {
    expect(request.url.path, '/api/floors');
    return http.Response(
      jsonEncode({
        'updated_at': '2026-10-08T15:00:00-04:00',
        'building': {
          'occupancy': 180,
          'capacity': 220,
          'busyness': 0.818,
          'status': status,
        },
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
  return ApiClient(client: mock);
}

Future<void> pumpApp(WidgetTester tester, ApiClient api) async {
  await tester.pumpWidget(BobstApp(api: api));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('overview shows building status', (tester) async {
    await pumpApp(tester, fakeApi(status: 'full'));

    expect(find.text('BOBST IS'), findsOneWidget);
    expect(find.text('FULL'), findsOneWidget);
    expect(find.text('180 people · 82% full'), findsOneWidget);
  });

  testWidgets('overview shows AVAILABLE when not full', (tester) async {
    await pumpApp(tester, fakeApi(status: 'available'));

    expect(find.text('AVAILABLE'), findsOneWidget);
  });

  testWidgets('floors tab shows per-floor headcount', (tester) async {
    await pumpApp(tester, fakeApi(status: 'full'));

    await tester.tap(find.byIcon(Icons.layers_outlined));
    await tester.pump();

    expect(find.text('Floor 5'), findsOneWidget);
    expect(find.text('180'), findsOneWidget);
    expect(find.text('Busy'), findsOneWidget);
  });
}
