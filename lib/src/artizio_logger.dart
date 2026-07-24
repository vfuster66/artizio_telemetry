import 'artizio_telemetry.dart';
import 'props_allowlist.dart';
import 'recent_event.dart';

/// Erreurs non fatales (codes métier stables).
abstract final class ArtizioLogger {
  ArtizioLogger._();

  static Future<void> error(
    String code, {
    Object? error,
    StackTrace? stackTrace,
    String? message,
    Map<String, String>? tags,
  }) async {
    final safeTags = ArtizioPropsAllowlist.sanitizeTags({
      'error_code': code,
      ...?tags,
    });

    ArtizioTelemetry.recentEvents.add(
      RecentEvent(
        at: DateTime.now().toUtc(),
        kind: 'error',
        code: code,
        message: message,
        error: error?.runtimeType.toString(),
      ),
    );

    ArtizioTelemetry.debugLog(
      'error $code'
      '${message == null ? '' : ' — $message'}'
      '${error == null ? '' : ' (${error.runtimeType})'}',
    );

    if (!ArtizioTelemetry.isEnabled) return;

    ArtizioTelemetry.backend.addBreadcrumb(
      code,
      category: 'error',
      data: safeTags,
    );

    if (error != null) {
      await ArtizioTelemetry.backend.captureException(
        error,
        stackTrace: stackTrace,
        code: code,
        // Pas de message UI / toString() libre vers le remote (risque PII).
        tags: safeTags,
      );
    } else {
      await ArtizioTelemetry.backend.captureMessage(
        code,
        code: code,
        tags: safeTags,
      );
    }
  }

  static Future<void> warning(
    String code, {
    String? message,
    Map<String, String>? tags,
  }) async {
    final safeTags = ArtizioPropsAllowlist.sanitizeTags({
      'error_code': code,
      ...?tags,
    });
    ArtizioTelemetry.recentEvents.add(
      RecentEvent(
        at: DateTime.now().toUtc(),
        kind: 'error',
        code: code,
        message: message ?? 'warning',
      ),
    );
    ArtizioTelemetry.debugLog('warning $code');
    if (!ArtizioTelemetry.isEnabled) return;
    await ArtizioTelemetry.backend.captureMessage(
      code,
      level: 'warning',
      code: code,
      tags: safeTags,
    );
  }
}
