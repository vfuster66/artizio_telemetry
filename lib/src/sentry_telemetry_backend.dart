import 'package:flutter/widgets.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'telemetry_backend.dart';

class SentryTelemetryBackend implements TelemetryBackend {
  @override
  Future<void> captureException(
    Object error, {
    StackTrace? stackTrace,
    String? code,
    String? message,
    Map<String, String>? tags,
  }) async {
    await Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (scope) {
        if (code != null) {
          scope.setTag('error_code', code);
          scope.fingerprint = ['{{ default }}', code];
        }
        if (message != null && message.isNotEmpty) {
          scope.setContexts('user_message', {'text': message});
        }
        tags?.forEach(scope.setTag);
      },
    );
  }

  @override
  Future<void> captureMessage(
    String message, {
    String level = 'error',
    String? code,
    Map<String, String>? tags,
  }) async {
    await Sentry.captureMessage(
      message,
      level: _level(level),
      withScope: (scope) {
        if (code != null) {
          scope.setTag('error_code', code);
          scope.fingerprint = [code];
        }
        tags?.forEach(scope.setTag);
      },
    );
  }

  @override
  void addBreadcrumb(
    String message, {
    String? category,
    Map<String, Object?>? data,
  }) {
    Sentry.addBreadcrumb(
      Breadcrumb(
        message: message,
        category: category,
        data: data == null
            ? null
            : {
                for (final e in data.entries)
                  if (e.value != null) e.key: e.value,
              },
      ),
    );
  }

  @override
  Future<void> track(
    String event, {
    Map<String, Object?>? props,
  }) async {
    addBreadcrumb(event, category: 'analytics', data: props);
    await Sentry.captureMessage(
      event,
      level: SentryLevel.info,
      withScope: (scope) {
        scope.setTag('analytics_event', event);
        scope.fingerprint = ['analytics', event];
        if (props != null && props.isNotEmpty) {
          scope.setContexts('analytics_props', {
            for (final e in props.entries)
              if (e.value != null) e.key: e.value,
          });
        }
      },
    );
  }

  @override
  List<NavigatorObserver> get navigatorObservers => [
        SentryNavigatorObserver(),
      ];

  @override
  void setTag(String key, String value) {
    Sentry.configureScope((scope) => scope.setTag(key, value));
  }

  @override
  void setContext(String key, Map<String, Object?> context) {
    Sentry.configureScope((scope) {
      scope.setContexts(key, context);
    });
  }

  static SentryLevel _level(String level) {
    switch (level.toLowerCase()) {
      case 'debug':
        return SentryLevel.debug;
      case 'info':
        return SentryLevel.info;
      case 'warning':
      case 'warn':
        return SentryLevel.warning;
      case 'fatal':
        return SentryLevel.fatal;
      default:
        return SentryLevel.error;
    }
  }
}
