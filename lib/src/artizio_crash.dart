import 'artizio_logger.dart';
import 'artizio_telemetry.dart';
import 'props_allowlist.dart';
import 'recent_event.dart';

/// Crashes / exceptions fatales ou quasi-fatales.
abstract final class ArtizioCrash {
  ArtizioCrash._();

  static Future<void> report(
    Object error, {
    StackTrace? stackTrace,
    String? code,
    String? message,
    Map<String, String>? tags,
  }) async {
    final eventCode = code ?? 'UNHANDLED';
    final safeTags = ArtizioPropsAllowlist.sanitizeTags({
      'error_code': eventCode,
      'fatal': 'true',
      ...?tags,
    });

    ArtizioTelemetry.recentEvents.add(
      RecentEvent(
        at: DateTime.now().toUtc(),
        kind: 'crash',
        code: eventCode,
        message: message,
        error: error.runtimeType.toString(),
      ),
    );
    ArtizioTelemetry.debugLog(
      'crash $eventCode (${error.runtimeType})',
    );
    await ArtizioTelemetry.backend.captureException(
      error,
      stackTrace: stackTrace,
      code: eventCode,
      tags: safeTags,
    );
  }

  /// Alias pratique — même chemin que [ArtizioLogger.error] pour cohérence.
  static Future<void> reportNonFatal(
    String code, {
    Object? error,
    StackTrace? stackTrace,
    String? message,
    Map<String, String>? tags,
  }) =>
      ArtizioLogger.error(
        code,
        error: error,
        stackTrace: stackTrace,
        message: message,
        tags: tags,
      );
}
