/// Configuration d’initialisation [ArtizioTelemetry.init].
class ArtizioTelemetryOptions {
  const ArtizioTelemetryOptions({
    required this.appName,
    this.dsn = '',
    this.environment,
    this.tracesSampleRate = 0.2,
    this.enableInDebug = false,
    this.debugLogEvents,
    this.release,
  });

  /// Identifiant suite : `frezio`, `trajio`, `surfacio`, `staggio`.
  final String appName;

  /// DSN Sentry. Vide = backend distant désactivé.
  final String dsn;

  /// Ex. `production`, `profile`, `debug`. Déduit si null.
  final String? environment;

  /// Sample rate des transactions perf Sentry (0–1).
  final double tracesSampleRate;

  /// Si false (défaut), les builds debug n’envoient rien à Sentry.
  final bool enableInDebug;

  /// Affiche les events / erreurs dans la console debug.
  /// Défaut : `true` hors release et hors `flutter test`.
  final bool? debugLogEvents;

  /// Override release Sentry (`app@version+build`). Sinon package_info.
  final String? release;

  bool get hasDsn => dsn.trim().isNotEmpty;
}
