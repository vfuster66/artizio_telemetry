import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'artizio_telemetry.dart';

/// Rapport de diagnostic exportable (texte).
abstract final class ArtizioDiagnostics {
  ArtizioDiagnostics._();

  /// Compteurs / flags anonymes acceptés dans [extras].
  static const allowedExtraKeys = <String>{
    'pro',
    'organizations',
    'expenses',
    'chantiers',
    'trips',
    'vehicles',
    'favorites',
  };

  /// Construit un rapport texte partageable.
  ///
  /// [extras] : compteurs anonymes uniquement (voir [allowedExtraKeys]).
  static Future<String> buildReport({
    Map<String, String>? extras,
  }) async {
    final buf = StringBuffer();
    final opts = ArtizioTelemetry.options;
    final info = await _packageInfo();

    buf.writeln('Artizio diagnostic report');
    buf.writeln('generated_at=${DateTime.now().toUtc().toIso8601String()}');
    buf.writeln('app=${opts?.appName ?? info?.appName ?? 'unknown'}');
    buf.writeln('version=${info?.version ?? '?'}');
    buf.writeln('build=${info?.buildNumber ?? '?'}');
    buf.writeln('package=${info?.packageName ?? '?'}');
    buf.writeln('platform=${_platformLabel()}');
    buf.writeln('os=${_osVersion()}');
    buf.writeln('locale=${PlatformDispatcher.instance.locale}');
    buf.writeln(
      'build_mode=${kReleaseMode ? 'release' : kProfileMode ? 'profile' : 'debug'}',
    );
    buf.writeln(
      'sentry_remote=${ArtizioTelemetry.isRemoteEnabled ? 'on' : 'off'}',
    );
    buf.writeln(
      'environment=${opts?.environment ?? '(default)'}',
    );
    final installId = ArtizioTelemetry.installId;
    if (installId != null) {
      buf.writeln('install_id=$installId');
    }

    final safeExtras = _sanitizeExtras(extras);
    if (safeExtras.isNotEmpty) {
      buf.writeln();
      buf.writeln('--- app ---');
      final keys = safeExtras.keys.toList()..sort();
      for (final key in keys) {
        buf.writeln('$key=${safeExtras[key]}');
      }
    }

    final recent = ArtizioTelemetry.recentEvents.items;
    buf.writeln();
    buf.writeln('--- recent_events (${recent.length}) ---');
    if (recent.isEmpty) {
      buf.writeln('(none)');
    } else {
      for (final e in recent.reversed) {
        buf.writeln(e.toString());
      }
    }

    buf.writeln();
    buf.writeln('end');
    return buf.toString();
  }

  static Map<String, String> _sanitizeExtras(Map<String, String>? extras) {
    if (extras == null || extras.isEmpty) return const {};
    final out = <String, String>{};
    for (final e in extras.entries) {
      final key = e.key.trim().toLowerCase();
      if (!allowedExtraKeys.contains(key)) continue;
      final value = e.value.trim();
      if (value.isEmpty) continue;
      // Uniquement bool / nombres (compteurs).
      if (value == 'true' || value == 'false' || int.tryParse(value) != null) {
        out[key] = value;
      }
    }
    return out;
  }

  static Future<PackageInfo?> _packageInfo() async {
    try {
      return await PackageInfo.fromPlatform();
    } catch (_) {
      return null;
    }
  }

  static String _platformLabel() {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isIOS) return 'ios';
      if (Platform.isAndroid) return 'android';
      if (Platform.isMacOS) return 'macos';
      if (Platform.isWindows) return 'windows';
      if (Platform.isLinux) return 'linux';
    } catch (_) {}
    return defaultTargetPlatform.name;
  }

  static String _osVersion() {
    if (kIsWeb) return 'web';
    try {
      return Platform.operatingSystemVersion;
    } catch (_) {
      return '?';
    }
  }
}
