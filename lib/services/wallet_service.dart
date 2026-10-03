import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Single source of truth for the player's economy + progression.
/// All offline: persisted to shared_preferences, survives app close.
class WalletService extends ChangeNotifier {
  static const _kCoins = 'coins';
  static const _kGems = 'gems';
  static const _kXp = 'xp';

  static const startingCoins = 10000;
  static const startingGems = 10;
  static const rescueAmount = 5000; // granted when broke
  static const xpPerLevel = 1000; // flat curve; tune later

  late SharedPreferences _prefs;
  int _coins = startingCoins;
  int _gems = startingGems;
  int _xp = 0;

  int get coins => _coins;
  int get gems => _gems;
  int get xp => _xp;

  /// Level 1 at 0 XP, +1 every [xpPerLevel].
  int get level => (_xp ~/ xpPerLevel) + 1;

  /// 0..1 progress toward the next level, for the XP bar.
  double get levelProgress => (_xp % xpPerLevel) / xpPerLevel;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    _coins = _prefs.getInt(_kCoins) ?? startingCoins;
    _gems = _prefs.getInt(_kGems) ?? startingGems;
    _xp = _prefs.getInt(_kXp) ?? 0;
    notifyListeners();
  }

  void _persist() {
    _prefs.setInt(_kCoins, _coins);
    _prefs.setInt(_kGems, _gems);
    _prefs.setInt(_kXp, _xp);
  }

  /// Returns false if the player can't afford [amount] (no change made).
  bool spendCoins(int amount) {
    if (amount <= 0 || _coins < amount) return false;
    _coins -= amount;
    _persist();
    notifyListeners();
    return true;
  }

  void addCoins(int amount) {
    if (amount <= 0) return;
    _coins += amount;
    _persist();
    notifyListeners();
  }

  void addGems(int amount) {
    if (amount <= 0) return;
    _gems += amount;
    _persist();
    notifyListeners();
  }

  /// XP is earned per spin/bet; may cross a level boundary.
  void addXp(int amount) {
    if (amount <= 0) return;
    _xp += amount;
    _persist();
    notifyListeners();
  }

  /// Never let the player hard-stop at zero. Caller shows the UI.
  bool get isBroke => _coins <= 0;

  void grantRescue() {
    if (!isBroke) return;
    _coins += rescueAmount;
    _persist();
    notifyListeners();
  }
}
