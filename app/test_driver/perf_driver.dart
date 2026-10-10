import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';

/// Writes a frame-timing summary to build/interactions.timeline_summary.json.
Future<void> main() {
  return integrationDriver(
    responseDataCallback: (data) async {
      if (data == null) return;
      final timeline = driver.Timeline.fromJson(
        data['interactions'] as Map<String, dynamic>,
      );
      final summary = driver.TimelineSummary.summarize(timeline);
      await summary.writeTimelineToFile(
        'interactions',
        pretty: true,
        includeSummary: true,
      );
    },
  );
}
