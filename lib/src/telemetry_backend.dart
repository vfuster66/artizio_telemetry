import 'package:flutter/widgets.dart';

/// Contrat backend (Sentry ou no-op).
abstract class TelemetryBackend {
  Future<void> captureException(
    Object error, {
    StackTrace? stackTrace,
    String? code,
    String? message,
    Map<String, String>? tags,
  });

  Future<void> captureMessage(
    String message, {
    String level = 'error',
    String? code,
    Map<String, String>? tags,
  });

  void addBreadcrumb(
    String message, {
    String? category,
    Map<String, Object?>? data,
  });

  Future<void> track(
    String event, {
    Map<String, Object?>? props,
  });

  List<NavigatorObserver> get navigatorObservers;

  void setTag(String key, String value);

  void setContext(String key, Map<String, Object?> context);
}
