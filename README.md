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
- Install ID : UUID local anonyme (`ArtizioInstallId`) — **jamais** posé comme `SentryUser.id`.
- Opt-out : `ArtizioTelemetry.setEnabled(false)` / `isEnabled` (prefs `artizio_telemetry_enabled`, défaut `true`). Quand désactivé, le backend distant no-op (crash + analytics).
- `beforeSend` : redaction e-mails, chemins absolus, `file://`, messages longs ; `request`/`url` effacés.

## Région Sentry (RGPD)

Préférer un **DSN hébergé en UE / Allemagne** (ou self-host EU). Ne pas utiliser une région France SaaS si elle n’est pas proposée ou si les données sortent hors cadre voulu — vérifier la résidence des events dans le projet Sentry.

## Apps

| App | Statut |
| --- | --- |
| Frezio | branché |
| Trajio | branché |
| Surfacio | branché |
| Staggio | branché |

Voir aussi `docs/artizio/observability.md`.
