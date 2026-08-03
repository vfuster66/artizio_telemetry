import 'package:flutter/widgets.dart';

import 'telemetry_backend.dart';

/// Backend silencieux (pas de DSN / debug).
class NoopTelemetryBackend implements TelemetryBackend {
  @override
  Future<void> captureException(
    Object error, {
    StackTrace? stackTrace,
    String? code,
    String? message,
    Map<String, String>? tags,
  }) async {}

  @override
  Future<void> captureMessage(
    String message, {
    String level = 'error',
    String? code,
    Map<String, String>? tags,
  }) async {}

  @override
  void addBreadcrumb(
    String message, {
    String? category,
    Map<String, Object?>? data,
  }) {}

  @override
  Future<void> track(String event, {Map<String, Object?>? props}) async {}

  @override
  List<NavigatorObserver> get navigatorObservers => const [];

  @override
  void setTag(String key, String value) {}

  @override
  void setContext(String key, Map<String, Object?> context) {}
}
