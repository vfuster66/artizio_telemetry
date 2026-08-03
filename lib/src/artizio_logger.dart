import 'artizio_telemetry.dart';
import 'privacy_scrubber.dart';
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
    final safeCode = ArtizioPropsAllowlist.sanitizeErrorCode(code);
    final safeTags = ArtizioPropsAllowlist.sanitizeTags({
      'error_code': safeCode,
      ...?tags,
    });

    ArtizioTelemetry.recentEvents.add(
      RecentEvent(
        at: DateTime.now().toUtc(),
        kind: 'error',
        code: safeCode,
        error: error?.runtimeType.toString(),
      ),
    );

    ArtizioTelemetry.debugLog(
      'error $safeCode'
      '${message == null ? '' : ' — ${ArtizioPrivacyScrubber.scrubText(message)}'}'
      '${error == null ? '' : ' (${error.runtimeType})'}',
    );

    if (!ArtizioTelemetry.isEnabled) return;

    ArtizioTelemetry.backend.addBreadcrumb(
      safeCode,
      category: 'error',
      data: safeTags,
    );

    if (error != null) {
      await ArtizioTelemetry.backend.captureException(
        error,
        stackTrace: stackTrace,
        code: safeCode,
        // Pas de message UI / toString() libre vers le remote (risque PII).
        tags: safeTags,
      );
    } else {
      await ArtizioTelemetry.backend.captureMessage(
        safeCode,
        code: safeCode,
        tags: safeTags,
      );
    }
  }

  static Future<void> warning(
    String code, {
    String? message,
    Map<String, String>? tags,
  }) async {
    final safeCode = ArtizioPropsAllowlist.sanitizeErrorCode(code);
    final safeTags = ArtizioPropsAllowlist.sanitizeTags({
      'error_code': safeCode,
      ...?tags,
    });
    ArtizioTelemetry.recentEvents.add(
      RecentEvent(at: DateTime.now().toUtc(), kind: 'error', code: safeCode),
    );
    ArtizioTelemetry.debugLog('warning $safeCode');
    if (!ArtizioTelemetry.isEnabled) return;
    await ArtizioTelemetry.backend.captureMessage(
      safeCode,
      level: 'warning',
      code: safeCode,
      tags: safeTags,
    );
  }
}
