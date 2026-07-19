import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Identifiant d’installation anonyme (UUID v4 local).
///
/// - Non dérivé d’un appareil, e-mail ou compte
/// - Persistant tant que les données app existent
/// - Renouvelé après désinstallation / effacement des données
abstract final class ArtizioInstallId {
  ArtizioInstallId._();

  static const prefsKey = 'artizio_install_id_v1';
  static String? _cached;

  /// UUID courant (crée et persiste si absent).
  static Future<String> getOrCreate() async {
    if (_cached != null) return _cached!;
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(prefsKey)?.trim();
    if (existing != null && existing.isNotEmpty) {
      _cached = existing;
      return existing;
    }
    final created = const Uuid().v4();
    await prefs.setString(prefsKey, created);
    _cached = created;
    return created;
  }

  /// Lecture synchrone du cache (après [getOrCreate]).
  static String? get cached => _cached;

  /// Efface le cache mémoire (tests). Ne touche pas prefs sauf [clearPersisted].
  static void debugClearCache() => _cached = null;

  /// Supprime l’ID persisté (tests / reset volontaire).
  static Future<void> clearPersisted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKey);
    _cached = null;
  }
}
