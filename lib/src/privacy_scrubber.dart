import 'package:sentry_flutter/sentry_flutter.dart';

import 'props_allowlist.dart';

/// Redaction PII pour envois Sentry ([beforeSend]).
abstract final class ArtizioPrivacyScrubber {
  ArtizioPrivacyScrubber._();

  /// Longueur max des messages / valeurs d’exception libres.
  static const maxFreeformLength = 200;

  /// Contextes Sentry SDK conservés (le reste est retiré).
  static const allowedContextKeys = <String>{
    'device',
    'os',
    'runtime',
    'runtimes',
    'app',
    'browser',
    'gpu',
    'culture',
    'trace',
    'response',
    'feedback',
    'flags',
  };

  static final _emailRe = RegExp(
    r'[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}',
  );
  static final _fileUrlRe = RegExp(
    r'file://\S+',
    caseSensitive: false,
  );
  static final _absPathRe = RegExp(
    r'(?:[A-Za-z]:\\|/(?:Users|home|var|tmp|private|data|Applications|Volumes|sdcard|storage)/)\S*',
    caseSensitive: false,
  );

  /// Redacte e-mails, `file://`, chemins absolus, puis tronque.
  static String scrubText(
    String input, {
    int maxLength = maxFreeformLength,
  }) {
    var s = input;
    s = s.replaceAll(_emailRe, '[redacted-email]');
    s = s.replaceAll(_fileUrlRe, '[redacted-file-url]');
    s = s.replaceAllMapped(_absPathRe, (_) => '[redacted-path]');
    if (s.length > maxLength) {
      s = '${s.substring(0, maxLength)}…';
    }
    return s;
  }

  /// Remplace un chemin de frame par son basename (sans dossier utilisateur).
  static String scrubPathField(String path) {
    final normalized = path.replaceAll('\\', '/');
    final slash = normalized.lastIndexOf('/');
    final base = slash >= 0 ? normalized.substring(slash + 1) : normalized;
    if (base.isEmpty) return '[redacted-path]';
    return scrubText(base, maxLength: 128);
  }

  /// Redacte récursivement String / Map / List ; conserve num/bool.
  static dynamic scrubValue(dynamic value) {
    if (value == null) return null;
    if (value is String) return scrubText(value);
    if (value is Map) {
      return <String, dynamic>{
        for (final e in value.entries) e.key.toString(): scrubValue(e.value),
      };
    }
    if (value is Iterable && value is! String) {
      return [for (final item in value) scrubValue(item)];
    }
    if (value is num || value is bool) return value;
    return scrubText(value.toString());
  }

  /// Applique la politique privacy sur un [SentryEvent].
  ///
  /// Retourne `null` pour abandonner l’envoi (opt-out).
  static SentryEvent? scrubEvent(
    SentryEvent event, {
    required bool enabled,
  }) {
    if (!enabled) return null;

    event.request = null;

    final msg = event.message;
    if (msg != null) {
      event.message = SentryMessage(
        scrubText(msg.formatted),
        template: msg.template == null ? null : scrubText(msg.template!),
        // params peuvent contenir e-mails / chemins ; on les vide.
        params: null,
      );
    }

    final exceptions = event.exceptions;
    if (exceptions != null) {
      for (final ex in exceptions) {
        final value = ex.value;
        if (value != null && value.isNotEmpty) {
          ex.value = scrubText(value);
        }
        _scrubStackTrace(ex.stackTrace);
      }
    }

    final threads = event.threads;
    if (threads != null) {
      for (final thread in threads) {
        _scrubStackTrace(thread.stacktrace);
      }
    }

    final crumbs = event.breadcrumbs;
    if (crumbs != null) {
      for (final c in crumbs) {
        final m = c.message;
        if (m != null && m.isNotEmpty) {
          c.message = scrubText(m);
        }
        final data = c.data;
        if (data != null && data.isNotEmpty) {
          c.data = {
            for (final e in data.entries) e.key: scrubValue(e.value),
          };
        }
      }
    }

    final culprit = event.culprit;
    if (culprit != null && culprit.isNotEmpty) {
      event.culprit = scrubText(culprit);
    }

    // extras : deny-by-default via allowlist (valeurs scalaires sûres).
    // ignore: deprecated_member_use
    final extra = event.extra;
    if (extra != null) {
      final safe = ArtizioPropsAllowlist.sanitize({
        for (final e in extra.entries) e.key: e.value,
      });
      // ignore: deprecated_member_use
      event.extra = safe.isEmpty ? null : Map<String, dynamic>.from(safe);
    }

    _scrubContexts(event.contexts);

    return event;
  }

  static void _scrubContexts(Contexts contexts) {
    final toRemove = <String>[];
    for (final key in contexts.keys) {
      if (!allowedContextKeys.contains(key)) {
        toRemove.add(key);
      }
    }
    for (final key in toRemove) {
      contexts.remove(key);
    }
  }

  static void _scrubStackTrace(SentryStackTrace? stackTrace) {
    if (stackTrace == null) return;
    for (final frame in stackTrace.frames) {
      final abs = frame.absPath;
      if (abs != null && abs.isNotEmpty) {
        frame.absPath = scrubPathField(abs);
      }
      final name = frame.fileName;
      if (name != null && name.isNotEmpty) {
        frame.fileName = scrubPathField(name);
      }
    }
  }
}
