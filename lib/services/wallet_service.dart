import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum CurrencyGainType { coin, gem }

class CurrencyGainEvent {
  final CurrencyGainType type;
  final int amount;
  final Offset? origin;
  const CurrencyGainEvent({
    required this.type,
    required this.amount,
    this.origin,
  });
}

/// A VIP club tier, earned by total coins wagered (real play), not XP.
class VipTier {
  final String name;
  final int threshold; // vip points required to reach this tier
  const VipTier(this.name, this.threshold);
}

/// Single source of truth for the player's economy + progression.
/// All offline: persisted to shared_preferences, survives app close.
class WalletService extends ChangeNotifier {
  static const _kSchema = 'wallet_schema';
  static const _schemaVersion = 2;

  static const _kCoins = 'coins';
  static const _kGems = 'gems';
  static const _kXp = 'xp';
  static const _kSpins = 'stat_spins';
  static const _kWon = 'stat_won';
  static const _kBiggest = 'stat_biggest';
  static const _kWagered = 'stat_wagered';
  static const _kGames = 'stat_games';

  static const startingCoins = 10000;
  static const startingGems = 10;
  static const rescueAmount = 5000; // granted when broke
  static const xpPerLevel = 1000; // flat curve; tune later

  /// Exchange rate: 1 gem converts to this many coins.
  static const gemToCoinRate = 2000;

  /// VIP ladder, keyed on lifetime wager (1 point per [vipPointPerWager] coins).
  static const vipPointPerWager = 1000;
  static const vipTiers = <VipTier>[
    VipTier('NOVA ROOKIE', 0),
    VipTier('STAR CADET', 50),
    VipTier('COMET BARON', 200),
    VipTier('NEBULA VIP', 750),
    VipTier('GALACTIC TYCOON', 2500),
    VipTier('COSMIC OMNI-LEGEND', 8000),
  ];

  late SharedPreferences _prefs;
  int _coins = startingCoins;
  int _gems = startingGems;
  int _xp = 0;

  // Career stats (persisted).
  int _totalSpins = 0;
  int _totalWon = 0;
  int _biggestWin = 0;
  int _totalWagered = 0;
  int _gamesPlayed = 0;

  final _gainStreamController = StreamController<CurrencyGainEvent>.broadcast();
  Stream<CurrencyGainEvent> get onCurrencyGain => _gainStreamController.stream;

  int get coins => _coins;
  int get gems => _gems;
  int get xp => _xp;

  int get totalSpins => _totalSpins;
  int get totalWon => _totalWon;
  int get biggestWin => _biggestWin;
  int get totalWagered => _totalWagered;
  int get gamesPlayed => _gamesPlayed;

  /// Level 1 at 0 XP, +1 every [xpPerLevel].
  int get level => (_xp ~/ xpPerLevel) + 1;

  /// 0..1 progress toward the next level, for the XP bar.
  double get levelProgress => (_xp % xpPerLevel) / xpPerLevel;

  // ---- VIP (wager-based, so it reflects real play, not just XP) ----

  int get vipPoints => _totalWagered ~/ vipPointPerWager;

  int get vipTierIndex {
    var idx = 0;
    for (var i = 0; i < vipTiers.length; i++) {
      if (vipPoints >= vipTiers[i].threshold) idx = i;
    }
    return idx;
  }

  VipTier get vipTier => vipTiers[vipTierIndex];

  /// 0..1 progress to the next VIP tier (1.0 at the top tier).
  double get vipProgress {
    final i = vipTierIndex;
    if (i >= vipTiers.length - 1) return 1.0;
    final floor = vipTiers[i].threshold;
    final ceil = vipTiers[i + 1].threshold;
    if (ceil <= floor) return 1.0;
    return ((vipPoints - floor) / (ceil - floor)).clamp(0.0, 1.0);
  }

  /// Points still needed for the next tier, or 0 at the top.
  int get vipPointsToNext {
    final i = vipTierIndex;
    if (i >= vipTiers.length - 1) return 0;
    return vipTiers[i + 1].threshold - vipPoints;
  }

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    _coins = _prefs.getInt(_kCoins) ?? startingCoins;
    _gems = _prefs.getInt(_kGems) ?? startingGems;
    _xp = _prefs.getInt(_kXp) ?? 0;
    _totalSpins = _prefs.getInt(_kSpins) ?? 0;
    _totalWon = _prefs.getInt(_kWon) ?? 0;
    _biggestWin = _prefs.getInt(_kBiggest) ?? 0;
    _totalWagered = _prefs.getInt(_kWagered) ?? 0;
    _gamesPlayed = _prefs.getInt(_kGames) ?? 0;
    _prefs.setInt(_kSchema, _schemaVersion); // migration anchor for future versions
    notifyListeners();
  }

  void _persist() {
    _prefs
      ..setInt(_kCoins, _coins)
      ..setInt(_kGems, _gems)
      ..setInt(_kXp, _xp)
      ..setInt(_kSpins, _totalSpins)
      ..setInt(_kWon, _totalWon)
      ..setInt(_kBiggest, _biggestWin)
      ..setInt(_kWagered, _totalWagered)
      ..setInt(_kGames, _gamesPlayed);
  }

  /// Returns false if the player can't afford [amount] (no change made).
  bool spendCoins(int amount) {
    if (amount <= 0 || _coins < amount) return false;
    _coins -= amount;
    _persist();
    notifyListeners();
    return true;
  }

  /// Returns false if the player can't afford [amount] gems (no change made).
  bool spendGems(int amount) {
    if (amount <= 0 || _gems < amount) return false;
    _gems -= amount;
    _persist();
    notifyListeners();
    return true;
  }

  void addCoins(int amount, {Offset? origin}) {
    if (amount <= 0) return;
    _coins += amount;
    _persist();
    notifyListeners();
    _gainStreamController.add(CurrencyGainEvent(
      type: CurrencyGainType.coin,
      amount: amount,
      origin: origin,
    ));
  }

  void addGems(int amount, {Offset? origin}) {
    if (amount <= 0) return;
    _gems += amount;
    _persist();
    notifyListeners();
    _gainStreamController.add(CurrencyGainEvent(
      type: CurrencyGainType.gem,
      amount: amount,
      origin: origin,
    ));
  }

  /// Convert [gems] into coins at [gemToCoinRate]. Returns the coins credited,
  /// or 0 if the player doesn't hold that many gems.
  int exchangeGemsForCoins(int gems, {Offset? origin}) {
    if (gems <= 0 || _gems < gems) return 0;
    _gems -= gems;
    final coins = gems * gemToCoinRate;
    _coins += coins;
    _persist();
    notifyListeners();
    _gainStreamController.add(CurrencyGainEvent(
      type: CurrencyGainType.coin,
      amount: coins,
      origin: origin,
    ));
    return coins;
  }

  /// XP is earned per spin/bet; may cross a level boundary.
  void addXp(int amount) {
    if (amount <= 0) return;
    _xp += amount;
    _persist();
    notifyListeners();
  }

  /// Record one completed spin: updates career stats and grants XP scaled to
  /// the wager (bigger bets → faster progression). [win] is the coins won on
  /// that spin (0 for a loss); the coins themselves are credited separately.
  void recordSpin({required int bet, required int win}) {
    _totalSpins++;
    if (bet > 0) _totalWagered += bet;
    if (win > 0) {
      _totalWon += win;
      if (win > _biggestWin) _biggestWin = win;
    }
    // XP scales with the bet, floored so even a 1-coin spin advances.
    _xp += bet <= 0 ? 1 : (bet ~/ 2).clamp(1, 2000);
    _persist();
    notifyListeners();
  }

  /// Record a win that isn't tied to a fresh paid spin (e.g. a bonus-round
  /// payout). Updates lifetime/biggest-win stats without counting a spin.
  void recordWin(int amount) {
    if (amount <= 0) return;
    _totalWon += amount;
    if (amount > _biggestWin) _biggestWin = amount;
    _persist();
    notifyListeners();
  }

  /// Count a game launch (career stat + used by daily missions upstream).
  void recordGameOpened() {
    _gamesPlayed++;
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

  @override
  void dispose() {
    _gainStreamController.close();
    super.dispose();
  }
}
