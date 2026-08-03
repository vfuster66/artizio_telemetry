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
- Opt-in : `ArtizioTelemetry.setEnabled(true)` / `isEnabled` (prefs `artizio_telemetry_enabled`, défaut `false`). Sans consentement enregistré, aucun crash ni événement analytics n’est envoyé.
- Identifiants : événements en `snake_case`, codes d’erreur en `UPPER_SNAKE_CASE` (64 caractères maximum). Une valeur libre invalide est remplacée par un identifiant neutre.
- `beforeSend` : messages libres et valeurs d’exception remplacés, utilisateur/requêtes supprimés, breadcrumbs filtrés et contextes limités aux données techniques `app`, `os`, `runtime`, `runtimes` et `trace`.
- Performance : désactivée par défaut (`tracesSampleRate: 0`) et soumise au même opt-in ; les noms de transaction sont validés et les données libres de spans supprimées avant envoi.
- Diagnostic partageable : les messages libres ne sont jamais inclus dans les événements récents.

## Région Sentry (RGPD)

Préférer un **DSN hébergé en UE / Allemagne** (ou self-host EU). Ne pas utiliser une région France SaaS si elle n’est pas proposée ou si les données sortent hors cadre voulu — vérifier la résidence des events dans le projet Sentry.

## Apps

| App | Statut |
| --- | --- |
| Frezio | branché |
| Trajio | branché |
| Surfacio | branché |
| Staggio | branché |

Voir aussi les [procédures d’exploitation Artizio](https://github.com/vfuster66/artizio/blob/main/docs/operations.md).

## Source canonique et intégrations applicatives

Ce dépôt est la source canonique. Dans le workspace Artizio, les applications pointent vers lui avec un lien symbolique local `packages/artizio_telemetry` (ignoré par Git). Il n’existe donc aucune copie à synchroniser.

```sh
./tool/check_workspace_links.sh
```

Cette commande vérifie que Frezio, Staggio, Surfacio et Trajio utilisent bien la source canonique.
