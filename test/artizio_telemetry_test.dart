import 'package:artizio_telemetry/artizio_telemetry.dart';
import 'package:artizio_telemetry/src/recent_event_buffer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ArtizioTelemetry.debugReset();
    await ArtizioInstallId.clearPersisted();
  });

  test('RecentEventBuffer keeps last N', () {
    final buf = RecentEventBuffer(capacity: 3);
    for (var i = 0; i < 5; i++) {
      buf.add(
        RecentEvent(
          at: DateTime.utc(2026, 1, 1, 0, 0, i),
          kind: 'error',
          code: 'E$i',
        ),
      );
    }
    expect(buf.items.map((e) => e.code), ['E2', 'E3', 'E4']);
  });

  test('Logger records locally without remote', () async {
    await ArtizioLogger.error('PDF_EXPORT_FAILED', message: 'disk full');
    expect(ArtizioTelemetry.recentEvents.items, hasLength(1));
    expect(ArtizioTelemetry.recentEvents.items.first.code, 'PDF_EXPORT_FAILED');
  });

  test('Analytics records locally', () async {
    await ArtizioAnalytics.track('receipt_added', props: {'source': 'camera'});
    expect(ArtizioTelemetry.recentEvents.items.single.code, 'receipt_added');
  });

  test('Allowlist drops banned and unknown props', () {
    final safe = ArtizioPropsAllowlist.sanitize({
      'source': 'camera',
      'merchant': 'Dupont SA',
      'client_name': 'Alice',
      'address': '12 rue X',
      'amount': '42.50',
      'filename': 'ticket.jpg',
      'ocr_text': 'TOTAL 12',
      'unknown_field': 'x',
      'format': 'pdf',
      'item_count_bucket': '100-200',
    });
    expect(safe.keys.toSet(), {'source', 'format', 'item_count_bucket'});
    expect(safe['source'], 'camera');
    expect(safe.containsKey('merchant'), isFalse);
  });

  test('Allowlist rejects path-like strings', () {
    final safe = ArtizioPropsAllowlist.sanitize({
      'source': '/tmp/secret.jpg',
      'format': 'csv',
    });
    expect(safe.keys.toSet(), {'format'});
  });

  test('Analytics strips PII props before recording', () async {
    await ArtizioAnalytics.track(
      'receipt_added',
      props: {
        'source': 'gallery',
        'merchant': 'Boulangerie',
        'amount': 1200,
      },
    );
    final msg = ArtizioTelemetry.recentEvents.items.single.message ?? '';
    expect(msg, contains('source=gallery'));
    expect(msg, isNot(contains('Boulangerie')));
    expect(msg, isNot(contains('1200')));
  });

  test('Install ID is stable UUID then renews after clear', () async {
    final a = await ArtizioInstallId.getOrCreate();
    final b = await ArtizioInstallId.getOrCreate();
    expect(a, b);
    expect(a.length, greaterThan(10));
    await ArtizioInstallId.clearPersisted();
    final c = await ArtizioInstallId.getOrCreate();
    expect(c, isNot(a));
  });

  test(
      'Diagnostics report omits banned extras and includes install_id after init',
      () async {
    await ArtizioTelemetry.init(
      options: const ArtizioTelemetryOptions(
        appName: 'frezio',
        debugLogEvents: false,
      ),
      appRunner: () async {},
    );
    await ArtizioLogger.error('ZIP_IMPORT_FAILED', error: StateError('bad'));
    final report = await ArtizioDiagnostics.buildReport(
      extras: {
        'expenses': '12',
        'active_org': 'SARL Dupont',
        'merchant': 'x',
      },
    );
    expect(report, contains('ZIP_IMPORT_FAILED'));
    expect(report, contains('expenses=12'));
    expect(report, contains('install_id='));
    expect(report, isNot(contains('Dupont')));
    expect(report, contains('sentry_remote=off'));
  });

  test('setEnabled persists and gates analytics remote path', () async {
    expect(ArtizioTelemetry.isEnabled, isTrue);
    await ArtizioTelemetry.setEnabled(false);
    expect(ArtizioTelemetry.isEnabled, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(ArtizioTelemetry.prefsEnabledKey), isFalse);

    await ArtizioAnalytics.track('receipt_added', props: {'source': 'camera'});
    expect(ArtizioTelemetry.recentEvents.items, hasLength(1));

    await ArtizioTelemetry.setEnabled(true);
    expect(ArtizioTelemetry.isEnabled, isTrue);
  });

  test('Privacy scrubber redacts email, paths, file URLs and truncates', () {
    final scrubbed = ArtizioPrivacyScrubber.scrubText(
      'Contact alice@example.com at /Users/virginie/secret.pdf '
      'or file:///tmp/ticket.jpg — ${'x' * 250}',
    );
    expect(scrubbed, contains('[redacted-email]'));
    expect(scrubbed, contains('[redacted-path]'));
    expect(scrubbed, contains('[redacted-file-url]'));
    expect(scrubbed, isNot(contains('alice@example.com')));
    expect(scrubbed, isNot(contains('/Users/virginie')));
    expect(scrubbed.length, lessThanOrEqualTo(ArtizioPrivacyScrubber.maxFreeformLength + 1));
  });

  test('beforeSend drops when disabled and clears request', () {
    final event = SentryEvent(
      message: SentryMessage('fail alice@example.com /Users/me/a.txt'),
      request: SentryRequest(url: 'https://api.example/v1?email=a@b.c'),
      exceptions: [
        SentryException(
          type: 'StateError',
          value: 'boom file:///tmp/x.pdf',
        ),
      ],
    );

    final dropped = ArtizioPrivacyScrubber.scrubEvent(event, enabled: false);
    expect(dropped, isNull);

    final kept = ArtizioPrivacyScrubber.scrubEvent(
      SentryEvent(
        message: SentryMessage('fail alice@example.com /Users/me/a.txt'),
        request: SentryRequest(url: 'https://api.example/v1'),
        exceptions: [
          SentryException(
            type: 'StateError',
            value: 'boom file:///tmp/x.pdf',
          ),
        ],
      ),
      enabled: true,
    );
    expect(kept, isNotNull);
    expect(kept!.request, isNull);
    expect(kept.message!.formatted, isNot(contains('alice@')));
    expect(kept.message!.formatted, isNot(contains('/Users/')));
    expect(kept.exceptions!.single.value, contains('[redacted-file-url]'));
  });
}
