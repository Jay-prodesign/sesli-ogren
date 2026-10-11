import 'dart:io';

/// Resident set size of the app process (B03). Available on Android and iOS.
int? currentRssBytes() => ProcessInfo.currentRss;

String? operatingSystemVersion() => '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
