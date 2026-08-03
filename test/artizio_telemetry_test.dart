import 'package:artizio_telemetry/artizio_telemetry.dart';
import 'package:artizio_telemetry/src/recent_event_buffer.dart';
import 'package:artizio_telemetry/src/telemetry_backend.dart';
import 'package:flutter/widgets.dart';
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
    await ArtizioLogger.error(
      'PDF_EXPORT_FAILED',
      message: 'Alice alice@example.com disk full',
    );
    expect(ArtizioTelemetry.recentEvents.items, hasLength(1));
    expect(ArtizioTelemetry.recentEvents.items.first.code, 'PDF_EXPORT_FAILED');
    expect(ArtizioTelemetry.recentEvents.items.first.message, isNull);
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
      'category': 'alice@example.com',
      'format': 'csv',
    });
    expect(safe.keys.toSet(), {'format'});
  });

  test('Analytics strips PII props before recording', () async {
    await ArtizioAnalytics.track(
      'receipt_added',
      props: {'source': 'gallery', 'merchant': 'Boulangerie', 'amount': 1200},
    );
    final msg = ArtizioTelemetry.recentEvents.items.single.message ?? '';
    expect(msg, contains('source=gallery'));
    expect(msg, isNot(contains('Boulangerie')));
    expect(msg, isNot(contains('1200')));
  });

  test('Identifiers reject free-form values instead of normalizing them', () {
    expect(
      ArtizioPropsAllowlist.sanitizeEventName('alice@example.com'),
      ArtizioPropsAllowlist.invalidEventName,
    );
    expect(
      ArtizioPropsAllowlist.sanitizeErrorCode('/Users/alice/secret.txt'),
      ArtizioPropsAllowlist.invalidErrorCode,
    );
  });

  test('Telemetry is opt-in by default', () {
    const options = ArtizioTelemetryOptions(appName: 'trajio');
    expect(options.enabledByDefault, isFalse);
    expect(options.tracesSampleRate, 0);
    expect(ArtizioTelemetry.isEnabled, isFalse);
  });

  test('Telemetry options reject an invalid traces sample rate', () {
    expect(
      () => ArtizioTelemetryOptions(appName: 'trajio', tracesSampleRate: 1.1),
      throwsAssertionError,
    );
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
      await ArtizioLogger.error(
        'ZIP_IMPORT_FAILED',
        error: StateError('bad'),
        message: 'Client Dupont alice@example.com',
      );
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
      expect(report, isNot(contains('alice@example.com')));
      expect(report, contains('sentry_remote=off'));
    },
  );

  test('setEnabled persists and gates analytics remote path', () async {
    expect(ArtizioTelemetry.isEnabled, isFalse);
    await ArtizioTelemetry.setEnabled(false);
    expect(ArtizioTelemetry.isEnabled, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(ArtizioTelemetry.prefsEnabledKey), isFalse);

    await ArtizioAnalytics.track('receipt_added', props: {'source': 'camera'});
    expect(ArtizioTelemetry.recentEvents.items, hasLength(1));

    await ArtizioTelemetry.setEnabled(true);
    expect(ArtizioTelemetry.isEnabled, isTrue);
  });

  test('init honors enabledByDefault when no preference is saved', () async {
    await ArtizioTelemetry.init(
      options: const ArtizioTelemetryOptions(
        appName: 'trajio',
        enabledByDefault: false,
      ),
      appRunner: () {},
    );

    expect(ArtizioTelemetry.isEnabled, isFalse);
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
    expect(
      scrubbed.length,
      lessThanOrEqualTo(ArtizioPrivacyScrubber.maxFreeformLength + 1),
    );
  });

  test('beforeSend drops when disabled and clears request', () {
    final event = SentryEvent(
      message: SentryMessage('fail alice@example.com /Users/me/a.txt'),
      request: SentryRequest(url: 'https://api.example/v1?email=a@b.c'),
      exceptions: [
        SentryException(type: 'StateError', value: 'boom file:///tmp/x.pdf'),
      ],
    );

    final dropped = ArtizioPrivacyScrubber.scrubEvent(event, enabled: false);
    expect(dropped, isNull);

    final kept = ArtizioPrivacyScrubber.scrubEvent(
      SentryEvent(
        message: SentryMessage('fail alice@example.com /Users/me/a.txt'),
        request: SentryRequest(url: 'https://api.example/v1'),
        exceptions: [
          SentryException(type: 'StateError', value: 'boom file:///tmp/x.pdf'),
        ],
      ),
      enabled: true,
    );
    expect(kept, isNotNull);
    expect(kept!.request, isNull);
    expect(kept.message!.formatted, '[redacted-message]');
    expect(kept.exceptions!.single.value, '[redacted-exception-message]');
  });

  test('scrubEvent clears SentryMessage.params', () {
    final kept = ArtizioPrivacyScrubber.scrubEvent(
      SentryEvent(
        message: SentryMessage(
          'hello alice@example.com',
          params: ['alice@example.com', '/Users/me/secret.txt'],
        ),
      ),
      enabled: true,
    );
    expect(kept!.message!.params, isNull);
    expect(kept.message!.formatted, '[redacted-message]');
  });

  test('scrubEvent applies the property allowlist to breadcrumbs', () {
    final kept = ArtizioPrivacyScrubber.scrubEvent(
      SentryEvent(
        breadcrumbs: [
          Breadcrumb(
            message: 'open alice@example.com',
            data: {
              'path': '/Users/virginie/ticket.pdf',
              'count': 3,
              'source': 'camera',
            },
          ),
        ],
      ),
      enabled: true,
    );
    final crumb = kept!.breadcrumbs!.single;
    expect(crumb.message, '[redacted-breadcrumb]');
    expect(crumb.data, {'source': 'camera'});
  });

  test('scrubEvent drops nested breadcrumb data', () {
    final kept = ArtizioPrivacyScrubber.scrubEvent(
      SentryEvent(
        breadcrumbs: [
          Breadcrumb(
            message: 'nested',
            data: {
              'meta': {
                'email': 'bob@example.com',
                'file': '/Users/bob/secret.pdf',
              },
              'tags': ['ok', 'file:///tmp/a.jpg'],
            },
          ),
        ],
      ),
      enabled: true,
    );
    expect(kept!.breadcrumbs!.single.data, isNull);
  });

  test('scrubEvent drops unknown extras and contexts', () {
    final kept = ArtizioPrivacyScrubber.scrubEvent(
      SentryEvent(
        // ignore: deprecated_member_use
        extra: {'source': 'camera', 'merchant': 'Dupont', 'secret_blob': 'pii'},
        user: SentryUser(email: 'alice@example.com'),
        serverName: 'alice-macbook',
        transaction: '/client/alice',
        tags: {'error_code': 'PDF_EXPORT_FAILED', 'email': 'alice@example.com'},
        contexts:
            Contexts(
                app: SentryApp(name: 'trajio'),
                device: SentryDevice(model: 'Pixel'),
              )
              ..['custom_pii'] = {'email': 'a@b.c'}
              ..['response'] = {'body': 'Alice Dupont'}
              ..['feedback'] = {'contact_email': 'alice@example.com'},
      ),
      enabled: true,
    );
    // ignore: deprecated_member_use
    expect(kept!.extra?.keys.toSet(), {'source'});
    // ignore: deprecated_member_use
    expect(kept.extra!['source'], 'camera');
    expect(kept.contexts.containsKey('custom_pii'), isFalse);
    expect(kept.contexts.app, isNotNull);
    expect(kept.contexts.device, isNull);
    expect(kept.contexts.containsKey('response'), isFalse);
    expect(kept.contexts.containsKey('feedback'), isFalse);
    expect(kept.user, isNull);
    expect(kept.serverName, isNull);
    expect(kept.transaction, ArtizioPropsAllowlist.invalidEventName);
    expect(kept.tags, {'error_code': 'PDF_EXPORT_FAILED'});
  });

  test('scrubEvent replaces frame absPath and fileName with basename', () {
    final kept = ArtizioPrivacyScrubber.scrubEvent(
      SentryEvent(
        exceptions: [
          SentryException(
            type: 'StateError',
            value: 'boom',
            stackTrace: SentryStackTrace(
              frames: [
                SentryStackFrame(
                  absPath: '/Users/virginie/dev/perso/app/lib/main.dart',
                  fileName: r'C:\Users\virginie\src\widget.dart',
                  function: 'main',
                ),
              ],
            ),
          ),
        ],
      ),
      enabled: true,
    );
    final frame = kept!.exceptions!.single.stackTrace!.frames.single;
    expect(frame.absPath, 'main.dart');
    expect(frame.fileName, 'widget.dart');
    expect(frame.absPath, isNot(contains('/Users/')));
    expect(frame.fileName, isNot(contains(r'C:\')));
  });

  test('Remote backend is gated and receives only sanitized values', () async {
    final backend = _RecordingBackend();
    ArtizioTelemetry.debugReset(backend: backend);

    await ArtizioAnalytics.track(
      'alice@example.com',
      props: {'source': 'camera', 'merchant': 'Dupont'},
    );
    await ArtizioLogger.error('/Users/alice/secret.txt');
    expect(backend.events, isEmpty);
    expect(backend.messages, isEmpty);

    await ArtizioTelemetry.setEnabled(true);
    await ArtizioAnalytics.track(
      'alice@example.com',
      props: {'source': 'camera', 'merchant': 'Dupont'},
    );
    await ArtizioLogger.error('/Users/alice/secret.txt');

    expect(backend.events.single, ArtizioPropsAllowlist.invalidEventName);
    expect(backend.eventProps.single, {'source': 'camera'});
    expect(backend.messages.single, ArtizioPropsAllowlist.invalidErrorCode);
    expect(backend.messageCodes.single, ArtizioPropsAllowlist.invalidErrorCode);
    expect(backend.allText, isNot(contains('alice@example.com')));
    expect(backend.allText, isNot(contains('/Users/alice')));
    expect(backend.allText, isNot(contains('Dupont')));
  });
}

class _RecordingBackend implements TelemetryBackend {
  final events = <String>[];
  final eventProps = <Map<String, Object?>>[];
  final messages = <String>[];
  final messageCodes = <String?>[];
  final exceptions = <Object>[];
  final breadcrumbs = <String>[];

  String get allText => [
    ...events,
    ...eventProps.map((value) => value.toString()),
    ...messages,
    ...messageCodes.whereType<String>(),
    ...breadcrumbs,
  ].join(' ');

  @override
  void addBreadcrumb(
    String message, {
    String? category,
    Map<String, Object?>? data,
  }) {
    breadcrumbs.add(message);
  }

  @override
  Future<void> captureException(
    Object error, {
    StackTrace? stackTrace,
    String? code,
    String? message,
    Map<String, String>? tags,
  }) async {
    exceptions.add(error);
  }

  @override
  Future<void> captureMessage(
    String message, {
    String level = 'error',
    String? code,
    Map<String, String>? tags,
  }) async {
    messages.add(message);
    messageCodes.add(code);
  }

  @override
  List<NavigatorObserver> get navigatorObservers => const [];

  @override
  void setContext(String key, Map<String, Object?> context) {}

  @override
  void setTag(String key, String value) {}

  @override
  Future<void> track(String event, {Map<String, Object?>? props}) async {
    events.add(event);
    eventProps.add(props ?? const {});
  }
}
