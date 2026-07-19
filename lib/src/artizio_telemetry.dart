import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'artizio_telemetry_options.dart';
import 'install_id.dart';
import 'noop_telemetry_backend.dart';
import 'props_allowlist.dart';
import 'recent_event_buffer.dart';
import 'sentry_telemetry_backend.dart';
import 'telemetry_backend.dart';
import 'telemetry_env.dart';

/// Bootstrap observabilité Artizio.
abstract final class ArtizioTelemetry {
  ArtizioTelemetry._();

  static TelemetryBackend _backend = NoopTelemetryBackend();
  static final RecentEventBuffer recentEvents = RecentEventBuffer();
  static ArtizioTelemetryOptions? _options;
  static bool _initialized = false;
  static String? _installId;

  static bool get isInitialized => _initialized;
  static bool get isRemoteEnabled => _backend is SentryTelemetryBackend;
  static ArtizioTelemetryOptions? get options => _options;
  static String? get installId => _installId;

  static TelemetryBackend get backend => _backend;

  static List<NavigatorObserver> get navigatorObservers =>
      _backend.navigatorObservers;

  /// Initialise le backend puis exécute [appRunner].
  ///
  /// Avec DSN + (release | enableInDebug) et hors `flutter test` :
  /// enveloppe [SentryFlutter.init]. Sinon : binding + [appRunner] seul.
  static Future<void> init({
    required ArtizioTelemetryOptions options,
    required FutureOr<void> Function() appRunner,
  }) async {
    WidgetsFlutterBinding.ensureInitialized();
    _options = options;
    _initialized = true;
    _installId = await ArtizioInstallId.getOrCreate();

    final useSentry = options.hasDsn &&
        !ArtizioTelemetryEnv.isFlutterTest &&
        (kReleaseMode || kProfileMode || options.enableInDebug);

    if (!useSentry) {
      _backend = NoopTelemetryBackend();
      debugLog(
        'init app=${options.appName} remote=off '
        'install_id=$_installId',
      );
      await appRunner();
      return;
    }

    _backend = SentryTelemetryBackend();
    final release = options.release ?? await _defaultRelease();
    final installId = _installId!;
    await SentryFlutter.init(
      (sentryOptions) {
        sentryOptions.dsn = options.dsn.trim();
        sentryOptions.tracesSampleRate = options.tracesSampleRate;
        sentryOptions.environment = options.environment ??
            (kReleaseMode
                ? 'production'
                : kProfileMode
                    ? 'profile'
                    : 'debug');
        sentryOptions.sendDefaultPii = false;
        sentryOptions.attachScreenshot = false;
        sentryOptions.considerInAppFramesByDefault = true;
        if (release != null) {
          sentryOptions.release = release;
        }
      },
      appRunner: () async {
        Sentry.configureScope((scope) {
          scope.setTag('artizio_app', options.appName);
          scope.setUser(SentryUser(id: installId));
        });
        debugLog(
          'init app=${options.appName} remote=on '
          'install_id=$installId',
        );
        await appRunner();
      },
    );
  }

  static void setTag(String key, String value) {
    final tags = ArtizioPropsAllowlist.sanitizeTags({key: value});
    tags.forEach(_backend.setTag);
  }

  static void setContext(String key, Map<String, Object?> context) {
    final safe = ArtizioPropsAllowlist.sanitize(context);
    if (safe.isEmpty) return;
    _backend.setContext(key, safe);
  }

  /// Log local (développement). Jamais en release ni sous `flutter test`
  /// sauf si [ArtizioTelemetryOptions.debugLogEvents] est forcé à `true`.
  static void debugLog(String message) {
    if (!_shouldDebugLog) return;
    debugPrint('[ArtizioTelemetry] $message');
  }

  static bool get _shouldDebugLog {
    final forced = _options?.debugLogEvents;
    if (forced != null) return forced;
    if (kReleaseMode) return false;
    if (ArtizioTelemetryEnv.isFlutterTest) return false;
    return true;
  }

  /// Remplace le backend (tests).
  @visibleForTesting
  static void debugReset({TelemetryBackend? backend}) {
    _backend = backend ?? NoopTelemetryBackend();
    _options = null;
    _initialized = false;
    _installId = null;
    recentEvents.clear();
    ArtizioInstallId.debugClearCache();
  }

  static Future<String?> _defaultRelease() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final app = _options?.appName ?? info.appName;
      return '$app@${info.version}+${info.buildNumber}';
    } catch (_) {
      return null;
    }
  }
}
