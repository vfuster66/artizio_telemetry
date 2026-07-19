/// Allowlist stricte des propriétés télémétrie (deny-by-default).
///
/// Toute clé hors liste est **jetée**. Les clés bannies le sont même si
/// elles apparaissaient un jour dans une liste élargie.
abstract final class ArtizioPropsAllowlist {
  ArtizioPropsAllowlist._();

  /// Clés acceptées (technique / agrégats anonymes uniquement).
  static const allowedKeys = <String>{
    'app',
    'version',
    'build',
    'platform',
    'os_version',
    'operation',
    'result',
    'duration_bucket',
    'item_count_bucket',
    'error_code',
    'source',
    'format',
    'kind',
    'product_id',
    'mock',
    'is_new',
    'has_attachment',
    'category',
    'round_trip',
    'fatal',
  };

  /// Clés explicitement interdites (données métier / PII).
  static const bannedKeys = <String>{
    'client_name',
    'address',
    'amount',
    'merchant',
    'comment',
    'filename',
    'file_path',
    'ocr_text',
    'departure',
    'arrival',
    'name',
    'email',
    'phone',
    'plate',
    'path',
    'text',
    'label',
    'title',
    'notes',
    'password',
    'token',
    'content',
    'active_org',
    'org_name',
  };

  static const int maxStringLength = 64;

  /// Filtre [input] : deny-by-default + valeurs scalaires sûres.
  static Map<String, Object?> sanitize(Map<String, Object?>? input) {
    if (input == null || input.isEmpty) return const {};
    final out = <String, Object?>{};
    for (final entry in input.entries) {
      final key = entry.key.trim().toLowerCase();
      if (key.isEmpty) continue;
      if (bannedKeys.contains(key)) continue;
      if (!allowedKeys.contains(key)) continue;
      final value = _sanitizeValue(entry.value);
      if (value != null) out[key] = value;
    }
    return out;
  }

  /// Variante tags String→String pour Sentry.
  static Map<String, String> sanitizeTags(Map<String, String>? input) {
    if (input == null || input.isEmpty) return const {};
    final raw = sanitize({
      for (final e in input.entries) e.key: e.value,
    });
    return {
      for (final e in raw.entries)
        if (e.value != null) e.key: '${e.value}',
    };
  }

  static Object? _sanitizeValue(Object? value) {
    if (value == null) return null;
    if (value is bool || value is int) return value;
    if (value is double) {
      if (value.isNaN || value.isInfinite) return null;
      return value;
    }
    if (value is Enum) return value.name;
    if (value is String) {
      var s = value.trim();
      if (s.isEmpty) return null;
      // Chemins / URI : jamais.
      if (s.contains('/') || s.contains('\\') || s.contains(':')) {
        return null;
      }
      if (s.length > maxStringLength) {
        s = s.substring(0, maxStringLength);
      }
      return s;
    }
    return null;
  }
}
