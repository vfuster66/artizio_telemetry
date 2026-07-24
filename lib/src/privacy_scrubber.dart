import 'package:sentry_flutter/sentry_flutter.dart';

/// Redaction PII pour envois Sentry ([beforeSend]).
abstract final class ArtizioPrivacyScrubber {
  ArtizioPrivacyScrubber._();

  /// Longueur max des messages / valeurs d’exception libres.
  static const maxFreeformLength = 200;

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
        params: msg.params,
      );
    }

    final exceptions = event.exceptions;
    if (exceptions != null) {
      for (final ex in exceptions) {
        final value = ex.value;
        if (value != null && value.isNotEmpty) {
          ex.value = scrubText(value);
        }
      }
    }

    final crumbs = event.breadcrumbs;
    if (crumbs != null) {
      for (final c in crumbs) {
        final m = c.message;
        if (m != null && m.isNotEmpty) {
          c.message = scrubText(m);
        }
      }
    }

    final culprit = event.culprit;
    if (culprit != null && culprit.isNotEmpty) {
      event.culprit = scrubText(culprit);
    }

    return event;
  }
}
