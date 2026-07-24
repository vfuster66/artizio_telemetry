import 'artizio_telemetry.dart';
import 'props_allowlist.dart';
import 'recent_event.dart';

/// Analytics produit (pas marketing).
abstract final class ArtizioAnalytics {
  ArtizioAnalytics._();

  static Future<void> track(
    String event, {
    Map<String, Object?>? props,
  }) async {
    final safe = ArtizioPropsAllowlist.sanitize(props);
    ArtizioTelemetry.recentEvents.add(
      RecentEvent(
        at: DateTime.now().toUtc(),
        kind: 'analytics',
        code: event,
        message: safe.entries.map((e) => '${e.key}=${e.value}').join(', '),
      ),
    );
    ArtizioTelemetry.debugLog(
      'track $event${safe.isEmpty ? '' : ' $safe'}',
    );
    if (!ArtizioTelemetry.isEnabled) return;
    await ArtizioTelemetry.backend.track(event, props: safe);
  }
}
