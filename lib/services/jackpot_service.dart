import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum JackpotTier { mini, minor, major, grand }

/// A locally-pooled progressive jackpot. Every bet seeds the pools a little;
/// winning a tier pays out the whole pool and resets it to its seed.
/// Fully offline + persisted, so pools keep growing across sessions.
class JackpotService extends ChangeNotifier {
  static const _kSchema = 'jackpot_schema';
  static const _schemaVersion = 1;

  static const _keys = {
    JackpotTier.mini: 'jp_mini',
    JackpotTier.minor: 'jp_minor',
    JackpotTier.major: 'jp_major',
    JackpotTier.grand: 'jp_grand',
  };

  /// Starting (and reset) value for each pool.
  static const seeds = {
    JackpotTier.mini: 5000,
    JackpotTier.minor: 25000,
    JackpotTier.major: 150000,
    JackpotTier.grand: 1000000,
  };

  /// Fraction of each bet that feeds each pool on every spin.
  static const _contribRate = {
    JackpotTier.mini: 0.02,
    JackpotTier.minor: 0.01,
    JackpotTier.major: 0.004,
    JackpotTier.grand: 0.002,
  };

  static const labels = {
    JackpotTier.mini: 'MINI',
    JackpotTier.minor: 'MINOR',
    JackpotTier.major: 'MAJOR',
    JackpotTier.grand: 'GRAND',
  };

  late SharedPreferences _prefs;
  final Map<JackpotTier, int> _pools = {...seeds};

  int value(JackpotTier t) => _pools[t] ?? seeds[t]!;
  String label(JackpotTier t) => labels[t]!;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    for (final t in JackpotTier.values) {
      _pools[t] = _prefs.getInt(_keys[t]!) ?? seeds[t]!;
    }
    _prefs.setInt(_kSchema, _schemaVersion);
    notifyListeners();
  }

  void _persist() {
    for (final t in JackpotTier.values) {
      _prefs.setInt(_keys[t]!, _pools[t]!);
    }
  }

  /// Seed every pool from a placed [bet]. Call once per paid spin.
  void contribute(int bet) {
    if (bet <= 0) return;
    for (final t in JackpotTier.values) {
      _pools[t] = _pools[t]! + (bet * _contribRate[t]!).round();
    }
    _persist();
    notifyListeners();
  }

  /// Pay out a tier: returns the pooled amount and resets that pool to its seed.
  int award(JackpotTier t) {
    final won = _pools[t]!;
    _pools[t] = seeds[t]!;
    _persist();
    notifyListeners();
    return won;
  }
}
