// Frame-timing check for the heaviest interactions. Run in profile mode:
//   flutter drive -d macos --profile \
//     --driver=test_driver/perf_driver.dart \
//     --target=integration_test/perf_test.dart
// Needs the backend running on localhost:8000.
import 'package:bobst/main.dart';
import 'package:bobst/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('floors list, floor page and areas stay smooth', (tester) async {
    await tester.pumpWidget(BobstApp(api: ApiClient()));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await tester.tap(find.text('Floors').last);
    await tester.pumpAndSettle();

    final list = find.byType(Scrollable).last;
    await binding.traceAction(() async {
      // Scroll the floor list down and back.
      for (var i = 0; i < 3; i++) {
        await tester.fling(list, const Offset(0, -600), 2000);
        await tester.pumpAndSettle();
        await tester.fling(list, const Offset(0, 600), 2000);
        await tester.pumpAndSettle();
      }
      // Open a floor (hero transition) and come back.
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('8th Floor'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
      }
      // Areas view: the longest list.
      await tester.tap(find.text('Areas'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await tester.fling(
          find.byType(Scrollable).last,
          const Offset(0, -900),
          3000,
        );
        await tester.pumpAndSettle();
      }
    }, reportKey: 'interactions');
  });
}
