# artizio_telemetry

Façade commune d’observabilité pour la suite Artizio.

```dart
ArtizioCrash.report(error, stackTrace: st);
ArtizioLogger.error('PDF_EXPORT_FAILED', error: e, stackTrace: st);
ArtizioAnalytics.track('receipt_added', props: {'source': 'camera'});
await ArtizioDiagnostics.buildReport(extras: {'expenses': '12'});
```

## Init

```dart
await ArtizioTelemetry.init(
  options: ArtizioTelemetryOptions(
    appName: 'frezio',
    dsn: const String.fromEnvironment('SENTRY_DSN'),
  ),
  appRunner: () async {
    runApp(MyApp());
  },
);
```

- `SENTRY_DSN` vide → pas d’envoi distant ; journal local + diagnostic restent actifs.
- Debug : pas d’envoi Sentry par défaut ; logs `[ArtizioTelemetry]` en console.
- `flutter test` : jamais d’envoi distant.
- Props : **allowlist deny-by-default** (`ArtizioPropsAllowlist`) — pas de PII.
- Install ID : UUID local anonyme (`ArtizioInstallId`).

## Apps

| App | Statut |
| --- | --- |
| Frezio | branché |
| Trajio | branché |
| Surfacio | branché |
| Staggio | branché |

Voir aussi `docs/artizio/observability.md`.
