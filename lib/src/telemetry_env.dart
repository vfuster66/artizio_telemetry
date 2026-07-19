import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Détection environnement test / debug pour la télémétrie.
abstract final class ArtizioTelemetryEnv {
  ArtizioTelemetryEnv._();

  /// `true` sous `flutter test` (variable `FLUTTER_TEST`).
  static bool get isFlutterTest {
    if (kIsWeb) return false;
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }
}
