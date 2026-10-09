import 'dart:convert';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:bobst/main.dart';
import 'package:bobst/services/api_client.dart';
import 'package:bobst/widgets/floor_plan.dart';
import 'package:flutter/material.dart';
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
  'sides': [name.toLowerCase()],
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
      if (request.url.path == '/api/rooms') {
        return http.Response(jsonEncode(roomsJson), 200);
      }
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

final roomsJson = {
  'groups': [
    {
      'id': 14114,
      'name': 'Group Study Rooms',
      'free_now': 1,
      'total': 2,
      'updated_at': '2026-10-09T17:00:00-04:00',
      'error': null,
      'rooms': [
        {
          'id': 1,
          'name': 'LL2 Group Study Room 10',
          'floor': 'LL2',
          'capacity': 6,
          'state': 'free',
          'free_until': '2026-10-09T19:30:00-04:00',
          'next_free_at': null,
          'booking_url': 'https://nyu.libcal.com/space/1',
        },
        {
          'id': 2,
          'name': 'LL2 Group Study Room 11',
          'floor': 'LL2',
          'capacity': 4,
          'state': 'booked',
          'free_until': null,
          'next_free_at': '2026-10-09T18:00:00-04:00',
          'booking_url': 'https://nyu.libcal.com/space/2',
        },
      ],
    },
  ],
};

Future<void> pumpApp(WidgetTester tester, ApiClient api) async {
  await tester.pumpWidget(BobstApp(api: api));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('overview shows building busyness', (tester) async {
    await pumpApp(tester, fakeApi());

    expect(find.text('BOBST IS'), findsOneWidget);
    expect(find.text('VERY BUSY'), findsOneWidget);
    expect(find.text('2,182 people  ·  76% full'), findsOneWidget);
    expect(find.text('Simulated data'), findsNothing);
  });

  testWidgets('overview label follows the six-step scale', (tester) async {
    await pumpApp(tester, fakeApi(buildingLevel: 'not_too_busy'));

    expect(find.text('NOT TOO BUSY'), findsOneWidget);
  });

  testWidgets('floor card opens its floor page and back', (tester) async {
    await pumpApp(tester, fakeApi());
    await tester.tap(find.text('Floors').last);
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    // Card: mini plan + headline, no area details yet.
    expect(find.byType(FloorPlanDiagram), findsOneWidget);
    expect(find.text('5th Floor'), findsOneWidget);
    expect(
      find.textContaining('Not too busy', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Quite empty'), findsNothing);

    await tester.tap(find.text('5th Floor'));
    await tester.pumpAndSettle();

    // Page: big plan labelled by side, plus a row per area.
    expect(find.text('East'), findsWidgets);
    expect(find.text('Very busy'), findsWidgets);
    expect(find.text('Quite empty'), findsWidgets);

    // Tapping a side selects it.
    await tester.tap(find.text('West').first);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('60 people'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('60 people'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Quite empty'), findsNothing);
    expect(find.text('5th Floor'), findsOneWidget);
  });

  testWidgets('rooms tab lists live availability', (tester) async {
    await pumpApp(tester, fakeApi());

    await tester.tap(find.text('Rooms').last);
    await tester.pump();
    await tester.pump();

    expect(find.text('Group Study Rooms  1/2 free'), findsOneWidget);
    expect(find.text('LL2 Group Study Room 10'), findsOneWidget);
    expect(find.textContaining('Free until'), findsOneWidget);
    expect(find.textContaining('Booked · free at'), findsOneWidget);

    await tester.tap(find.byType(AdaptiveSwitch));
    await tester.pump();
    expect(find.text('LL2 Group Study Room 11'), findsNothing);
  });

  testWidgets('floors tab sorts and filters areas', (tester) async {
    await pumpApp(tester, fakeApi());
    await tester.tap(find.text('Floors').last);
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    await tester.tap(find.text('Areas'));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    double y(String label) => tester.getTopLeft(find.text(label)).dy;

    // Building order keeps the backend's order: East then West.
    expect(y('5th Floor East'), lessThan(y('5th Floor West')));

    Future<void> pick(String option) async {
      await tester.tap(find.byIcon(Icons.filter_list));
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
      await tester.tap(find.text(option).last);
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
    }

    await pick('Least busy first');
    expect(y('5th Floor West'), lessThan(y('5th Floor East')));
    expect(find.text('Least busy first · Any noise'), findsOneWidget);

    await pick('Quiet');
    expect(find.text('5th Floor West'), findsOneWidget);
    expect(find.text('5th Floor East'), findsNothing);
  });
}
