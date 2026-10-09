import 'dart:convert';

import 'package:bobst/main.dart';
import 'package:bobst/services/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> area(
  String name,
  String noise,
  int people,
  String level,
) => {
  'id': name.toLowerCase(),
  'name': name,
  'label': '5th Floor $name',
  'noise': noise,
  'occupancy': people,
  'capacity': 70,
  'fullness': people / 70,
  'busyness': level,
};

ApiClient fakeApi({String buildingLevel = 'very_busy'}) {
  final east = area('East', 'talkative', 60, 'very_busy');
  final west = area('West', 'quiet', 12, 'quite_empty');
  return ApiClient(
    client: MockClient((request) async {
      expect(request.url.path, '/api/status');
      return http.Response(
        jsonEncode({
          'updated_at': '2026-10-08T15:00:00-04:00',
          'building': {
            'occupancy': 2182,
            'capacity': 2860,
            'fullness': 0.763,
            'busyness': buildingLevel,
          },
          'best_spots': {'quiet': west, 'talkative': east},
          'floors': [
            {
              'id': '5',
              'name': '5th Floor',
              'noise': 'mixed',
              'occupancy': 72,
              'capacity': 140,
              'fullness': 0.514,
              'busyness': 'not_too_busy',
              'areas': [east, west],
            },
          ],
        }),
        200,
      );
    }),
  );
}

Future<void> pumpApp(WidgetTester tester, ApiClient api) async {
  await tester.pumpWidget(BobstApp(api: api));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('overview shows building busyness and best spots', (
    tester,
  ) async {
    await pumpApp(tester, fakeApi());

    expect(find.text('BOBST IS'), findsOneWidget);
    expect(find.text('VERY BUSY'), findsOneWidget);
    expect(find.text('2,182 people  ·  76% full'), findsOneWidget);
    expect(find.text('5th Floor West'), findsOneWidget);
    expect(find.text('12 people  ·  17% full'), findsOneWidget);
    expect(find.text('5th Floor East'), findsOneWidget);
    expect(find.text('SIMULATED'), findsNothing);
  });

  testWidgets('overview label follows the six-step scale', (tester) async {
    await pumpApp(tester, fakeApi(buildingLevel: 'not_too_busy'));

    expect(find.text('NOT TOO BUSY'), findsOneWidget);
  });

  testWidgets('floors tab shows headcount and expands into areas', (
    tester,
  ) async {
    await pumpApp(tester, fakeApi());

    await tester.tap(find.text('Floors').last);
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    expect(find.text('5th Floor'), findsOneWidget);
    expect(find.text('72'), findsOneWidget);
    expect(find.text('Not too busy'), findsOneWidget);
    expect(find.text('60 people  ·  Very busy'), findsNothing);

    await tester.tap(find.text('5th Floor'));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    expect(find.text('60 people  ·  Very busy'), findsOneWidget);
    expect(find.text('12 people  ·  Quite empty'), findsOneWidget);
  });
}
