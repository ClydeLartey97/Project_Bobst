import 'dart:convert';

import 'package:bobst/main.dart';
import 'package:bobst/services/api_client.dart';
import 'package:bobst/widgets/building_view.dart';
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

  testWidgets('rooms tab lists live availability', (tester) async {
    await pumpApp(tester, fakeApi());

    await tester.tap(find.text('Rooms').last);
    await tester.pump();
    await tester.pump();

    expect(find.text('Group Study Rooms  1/2'), findsOneWidget);
    expect(find.text('LL2 Group Study Room 10'), findsOneWidget);
    expect(find.textContaining('Free until'), findsOneWidget);
    expect(find.textContaining('Booked · free at'), findsOneWidget);

    await tester.tap(find.text('Free right now only'));
    await tester.pump();
    expect(find.text('LL2 Group Study Room 11'), findsNothing);
  });

  testWidgets('building turns 3D when dragged and snaps back flat', (
    tester,
  ) async {
    await pumpApp(tester, fakeApi());
    await tester.tap(find.text('Building').last);
    await tester.pump();

    final view = find.byType(BuildingView);
    BuildingViewState state() => tester.state<BuildingViewState>(view);
    expect(state().isFlat, isTrue);

    // A big drag rotates it well away from the front: stays 3D.
    await tester.drag(view, const Offset(150, 40));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(state().isFlat, isFalse);
    expect(find.byTooltip('Flat view'), findsOneWidget);

    await tester.tap(find.byTooltip('Flat view'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(state().isFlat, isTrue);

    // A small nudge near the front snaps straight back to flat.
    await tester.drag(view, const Offset(10, 0));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(state().isFlat, isTrue);
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

    await tester.tap(find.text('Building order'));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    await tester.tap(find.text('Least busy first').last);
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    expect(y('5th Floor West'), lessThan(y('5th Floor East')));

    await tester.tap(find.widgetWithText(ChoiceChip, 'Quiet'));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    expect(find.text('5th Floor West'), findsOneWidget);
    expect(find.text('5th Floor East'), findsNothing);
  });
}
