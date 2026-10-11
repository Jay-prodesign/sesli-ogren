import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';

/// Host-side driver: stores the Flutter timeline summary and the P1 report under build/.
Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    if (data == null) return;
    final timeline = driver.Timeline.fromJson(data['timeline'] as Map<String, dynamic>);
    await driver.TimelineSummary.summarize(timeline).writeTimelineToFile('p1_timeline', pretty: true);
    await writeResponseData({'p1_report': data['p1_report']}, testOutputFilename: 'p1_report');
  },
);
