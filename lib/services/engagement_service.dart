import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'wallet_service.dart';

class Gift {
  final int id;
  final String title;
  final int coins;
  final int gems;
  const Gift(this.id, this.title, this.coins, this.gems);

  Map<String, dynamic> toJson() =>
      {'id': id, 'title': title, 'coins': coins, 'gems': gems};
  factory Gift.fromJson(Map<String, dynamic> j) =>
      Gift(j['id'], j['title'], j['coins'], j['gems']);
}

class DailyReward {
  final int day; // 1..7
  final int coins;
  final int gems;
  const DailyReward(this.day, this.coins, this.gems);
}

/// One wedge on the Lucky Wheel. [weight] controls how often it lands.
class WheelPrize {
  final String label;
  final int coins;
  final int gems;
  final int weight;
  const WheelPrize(this.label, this.coins, this.gems, this.weight);
}

/// Result of a wheel spin: which wedge, and what it paid.
class WheelResult {
  final int index;
  final WheelPrize prize;
  const WheelResult(this.index, this.prize);
}

enum MissionType { spins, winCoins, bigWins, playGames }

/// A daily mission template. Progress/claimed live in the service, keyed by slot.
class MissionTemplate {
  final MissionType type;
  final String title;
  final int target;
  final int rewardCoins;
  final int rewardGems;
  const MissionTemplate(
      this.type, this.title, this.target, this.rewardCoins, this.rewardGems);
}

/// A live mission (template + current progress + claimed state) for the UI.
class Mission {
  final int slot;
  final MissionTemplate template;
  final int progress;
  final bool claimed;
  const Mission(this.slot, this.template, this.progress, this.claimed);

  MissionType get type => template.type;
  String get title => template.title;
  int get target => template.target;
  int get rewardCoins => template.rewardCoins;
  int get rewardGems => template.rewardGems;
  bool get complete => progress >= target;
  bool get claimable => complete && !claimed;
  double get fraction => (progress / target).clamp(0.0, 1.0);
}

/// All offline, timestamp-based retention mechanics:
/// 7-day daily streak, a randomized Lucky Wheel, hourly free coins, a mailbox
/// of gifts, persisted store faucets, and rotating daily missions.
class EngagementService extends ChangeNotifier {
  static const _kSchema = 'engagement_schema';
  static const _schemaVersion = 2;

  static const _kStreakDate = 'streak_date';
  static const _kStreakDay = 'streak_day';
  static const _kHourly = 'hourly_last';
  static const _kMailbox = 'mailbox';
  static const _kGiftSeq = 'gift_seq';
  static const _kLastLevel = 'last_level';
  static const _kWheelDate = 'wheel_date';
  static const _kStorePackDate = 'storepack_date';
  static const _kFlashDate = 'flashdeal_date';
  static const _kMissionDate = 'mission_date';
  static const _kMissionProgress = 'mission_progress';
  static const _kMissionClaimed = 'mission_claimed';
  static const _kGamesToday = 'games_today';

  static const hourlyCoins = 1000;
  static const hourlyCooldown = Duration(hours: 1);

  /// Escalating 7-day ladder (coins, +gems on day 7).
  static const ladder = <DailyReward>[
    DailyReward(1, 2000, 0),
    DailyReward(2, 3000, 0),
    DailyReward(3, 5000, 0),
    DailyReward(4, 8000, 1),
    DailyReward(5, 12000, 2),
    DailyReward(6, 20000, 3),
    DailyReward(7, 50000, 5),
  ];

  /// The Lucky Wheel wedges (variable reward — this is what makes it a wheel,
  /// not a fixed daily). Weights make small prizes common, jackpots rare.
  static const wheelSegments = <WheelPrize>[
    WheelPrize('2K', 2000, 0, 24),
    WheelPrize('5K', 5000, 0, 20),
    WheelPrize('10K', 10000, 0, 14),
    WheelPrize('3 GEMS', 0, 3, 12),
    WheelPrize('25K', 25000, 0, 9),
    WheelPrize('10 GEMS', 0, 10, 6),
    WheelPrize('75K', 75000, 0, 3),
    WheelPrize('JACKPOT 250K', 250000, 5, 1),
  ];

  /// Daily store free-pack contents.
  static const storePackCoins = 10000;
  static const storePackGems = 5;

  /// Daily flash-deal contents (a discounted premium bundle).
  static const flashDealCoins = 100000;
  static const flashDealGems = 10;
  static const flashDealGemCost = 20; // paid in gems, not free

  /// Rotating mission pool; 3 are active each day.
  static const _missionPool = <MissionTemplate>[
    MissionTemplate(MissionType.spins, 'Spin 20 times', 20, 5000, 0),
    MissionTemplate(MissionType.spins, 'Spin 60 times', 60, 15000, 1),
    MissionTemplate(MissionType.winCoins, 'Win 15,000 coins', 15000, 5000, 0),
    MissionTemplate(MissionType.winCoins, 'Win 60,000 coins', 60000, 12000, 1),
    MissionTemplate(MissionType.bigWins, 'Land a Big Win', 1, 6000, 0),
    MissionTemplate(MissionType.bigWins, 'Land 3 Big Wins', 3, 8000, 2),
    MissionTemplate(MissionType.playGames, 'Play 2 different games', 2, 5000, 0),
    MissionTemplate(MissionType.playGames, 'Play 3 different games', 3, 9000, 1),
  ];
  static const missionSlots = 3;

  late SharedPreferences _prefs;
  String _streakDate = '';
  int _streakDay = 0;
  int _hourlyLast = 0;
  int _giftSeq = 0;
  List<Gift> _mailbox = [];

  String _wheelDate = '';
  String _storePackDate = '';
  String _flashDate = '';

  String _missionDate = '';
  List<int> _missionProgress = List.filled(missionSlots, 0);
  List<bool> _missionClaimed = List.filled(missionSlots, false);
  Set<String> _gamesToday = {};

  List<Gift> get mailbox => List.unmodifiable(_mailbox);
  int get unreadCount => _mailbox.length;

  Future<void> load(WalletService wallet) async {
    _prefs = await SharedPreferences.getInstance();
    _streakDate = _prefs.getString(_kStreakDate) ?? '';
    _streakDay = _prefs.getInt(_kStreakDay) ?? 0;
    _hourlyLast = _prefs.getInt(_kHourly) ?? 0;
    _giftSeq = _prefs.getInt(_kGiftSeq) ?? 0;
    _mailbox = _decodeMailbox(_prefs.getString(_kMailbox));
    _wheelDate = _prefs.getString(_kWheelDate) ?? '';
    _storePackDate = _prefs.getString(_kStorePackDate) ?? '';
    _flashDate = _prefs.getString(_kFlashDate) ?? '';

    _missionDate = _prefs.getString(_kMissionDate) ?? '';
    _missionProgress = _decodeIntList(_prefs.getString(_kMissionProgress),
        length: missionSlots);
    _missionClaimed = _decodeBoolList(_prefs.getString(_kMissionClaimed),
        length: missionSlots);
    _gamesToday = (_prefs.getStringList(_kGamesToday) ?? const []).toSet();
    _ensureMissionsForToday();

    _prefs.setInt(_kSchema, _schemaVersion);
    syncLevelRewards(wallet);
    notifyListeners();
  }

  // Corrupt-save hardening: never let a bad stored string crash launch.
  static List<Gift> _decodeMailbox(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Gift.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static List<int> _decodeIntList(String? raw, {required int length}) {
    try {
      final list = (jsonDecode(raw ?? '[]') as List).cast<int>();
      return List.generate(length, (i) => i < list.length ? list[i] : 0);
    } catch (_) {
      return List.filled(length, 0);
    }
  }

  static List<bool> _decodeBoolList(String? raw, {required int length}) {
    try {
      final list = (jsonDecode(raw ?? '[]') as List).cast<bool>();
      return List.generate(length, (i) => i < list.length ? list[i] : false);
    } catch (_) {
      return List.filled(length, false);
    }
  }

  // ---- Daily streak ----

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool get canClaimDaily => _streakDate != _dateKey(DateTime.now());

  /// The day the player would claim next (1..7), shown in the UI.
  int get nextStreakDay {
    final now = DateTime.now();
    if (_streakDate == _dateKey(now.subtract(const Duration(days: 1)))) {
      return (_streakDay % 7) + 1; // consecutive → advance (wraps after 7)
    }
    return _streakDate == _dateKey(now) ? _streakDay : 1; // today, or reset
  }

  int get currentStreakDay => _streakDay;

  DailyReward? claimDaily(WalletService wallet) {
    if (!canClaimDaily) return null;
    final day = nextStreakDay;
    final r = ladder[day - 1];
    _streakDate = _dateKey(DateTime.now());
    _streakDay = day;
    wallet.addCoins(r.coins);
    wallet.addGems(r.gems);
    _prefs
      ..setString(_kStreakDate, _streakDate)
      ..setInt(_kStreakDay, _streakDay);
    notifyListeners();
    return r;
  }

  // ---- Lucky Wheel (separate once-a-day randomized reward) ----

  bool get canSpinWheel => _wheelDate != _dateKey(DateTime.now());

  Duration get wheelResetRemaining {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return tomorrow.difference(now);
  }

  int _pickWheelIndex(Random rng) {
    final total =
        wheelSegments.fold<int>(0, (a, s) => a + s.weight);
    var r = rng.nextInt(total);
    for (var i = 0; i < wheelSegments.length; i++) {
      if (r < wheelSegments[i].weight) return i;
      r -= wheelSegments[i].weight;
    }
    return wheelSegments.length - 1;
  }

  /// Spin the wheel once per day. Returns null if already spun today.
  WheelResult? spinDailyWheel(WalletService wallet, {Random? rng}) {
    if (!canSpinWheel) return null;
    final index = _pickWheelIndex(rng ?? Random());
    final prize = wheelSegments[index];
    _wheelDate = _dateKey(DateTime.now());
    wallet.addCoins(prize.coins);
    wallet.addGems(prize.gems);
    _prefs.setString(_kWheelDate, _wheelDate);
    notifyListeners();
    return WheelResult(index, prize);
  }

  // ---- Hourly free coins ----

  bool get canClaimHourly =>
      DateTime.now().millisecondsSinceEpoch - _hourlyLast >=
      hourlyCooldown.inMilliseconds;

  Duration get hourlyRemaining {
    final elapsed = DateTime.now().millisecondsSinceEpoch - _hourlyLast;
    final left = hourlyCooldown.inMilliseconds - elapsed;
    return left <= 0 ? Duration.zero : Duration(milliseconds: left);
  }

  bool claimHourly(WalletService wallet) {
    if (!canClaimHourly) return false;
    _hourlyLast = DateTime.now().millisecondsSinceEpoch;
    wallet.addCoins(hourlyCoins);
    _prefs.setInt(_kHourly, _hourlyLast);
    notifyListeners();
    return true;
  }

  // ---- Store faucets (persisted daily gating) ----

  bool get canClaimStorePack => _storePackDate != _dateKey(DateTime.now());

  /// Claim the free daily store pack. Returns false if already claimed today.
  bool claimStorePack(WalletService wallet) {
    if (!canClaimStorePack) return false;
    _storePackDate = _dateKey(DateTime.now());
    wallet.addCoins(storePackCoins);
    wallet.addGems(storePackGems);
    _prefs.setString(_kStorePackDate, _storePackDate);
    notifyListeners();
    return true;
  }

  bool get canClaimFlashDeal => _flashDate != _dateKey(DateTime.now());

  Duration get flashResetRemaining => wheelResetRemaining;

  /// Buy the discounted flash deal with gems. Returns false if already taken
  /// today or the player can't afford the gem cost.
  bool claimFlashDeal(WalletService wallet) {
    if (!canClaimFlashDeal) return false;
    if (!wallet.spendGems(flashDealGemCost)) return false;
    _flashDate = _dateKey(DateTime.now());
    wallet.addCoins(flashDealCoins);
    wallet.addGems(flashDealGems);
    _prefs.setString(_kFlashDate, _flashDate);
    notifyListeners();
    return true;
  }

  // ---- Daily missions ----

  /// Deterministic 3-mission selection for a given date, so everyone on the
  /// same day gets the same rotation and it changes every day.
  static List<int> _missionSlotsForDate(String dateKey) {
    final seed = dateKey.hashCode & 0x7fffffff;
    final picks = <int>[];
    var cursor = seed % _missionPool.length;
    while (picks.length < missionSlots) {
      if (!picks.contains(cursor)) picks.add(cursor);
      cursor = (cursor + 1 + (seed % 3)) % _missionPool.length;
    }
    return picks;
  }

  List<int> get _todaySlots => _missionSlotsForDate(_dateKey(DateTime.now()));

  void _ensureMissionsForToday() {
    final today = _dateKey(DateTime.now());
    if (_missionDate == today) return;
    _missionDate = today;
    _missionProgress = List.filled(missionSlots, 0);
    _missionClaimed = List.filled(missionSlots, false);
    _gamesToday = {};
    _persistMissions();
  }

  List<Mission> get missions {
    _ensureMissionsForToday();
    final slots = _todaySlots;
    return [
      for (var i = 0; i < missionSlots; i++)
        Mission(i, _missionPool[slots[i]], _missionProgress[i],
            _missionClaimed[i]),
    ];
  }

  int get claimableMissionCount =>
      missions.where((m) => m.claimable).length;

  void _bumpMissions(MissionType type, int by, {int? absolute}) {
    _ensureMissionsForToday();
    final slots = _todaySlots;
    var changed = false;
    for (var i = 0; i < missionSlots; i++) {
      final t = _missionPool[slots[i]];
      if (t.type != type) continue;
      final next = absolute ?? (_missionProgress[i] + by);
      final capped = next.clamp(0, t.target);
      if (capped != _missionProgress[i]) {
        _missionProgress[i] = capped;
        changed = true;
      }
    }
    if (changed) {
      _persistMissions();
      notifyListeners();
    }
  }

  /// Gameplay hooks — call these from the game screens / lobby.
  void recordSpins(int n) => _bumpMissions(MissionType.spins, n);
  void recordWinCoins(int amount) {
    if (amount > 0) _bumpMissions(MissionType.winCoins, amount);
  }

  void recordBigWin() => _bumpMissions(MissionType.bigWins, 1);

  void recordGameOpened(String gameId) {
    _ensureMissionsForToday();
    if (_gamesToday.add(gameId)) {
      _bumpMissions(MissionType.playGames, 0, absolute: _gamesToday.length);
      _persistMissions();
    }
  }

  /// Claim a completed mission's reward. Returns false if not claimable.
  bool claimMission(WalletService wallet, int slot) {
    _ensureMissionsForToday();
    if (slot < 0 || slot >= missionSlots) return false;
    final t = _missionPool[_todaySlots[slot]];
    if (_missionProgress[slot] < t.target || _missionClaimed[slot]) {
      return false;
    }
    _missionClaimed[slot] = true;
    wallet.addCoins(t.rewardCoins);
    wallet.addGems(t.rewardGems);
    _persistMissions();
    notifyListeners();
    return true;
  }

  void _persistMissions() {
    _prefs
      ..setString(_kMissionDate, _missionDate)
      ..setString(_kMissionProgress, jsonEncode(_missionProgress))
      ..setString(_kMissionClaimed, jsonEncode(_missionClaimed))
      ..setStringList(_kGamesToday, _gamesToday.toList());
  }

  // ---- Mailbox ----

  void claimGift(WalletService wallet, int id) {
    final i = _mailbox.indexWhere((g) => g.id == id);
    if (i < 0) return;
    final g = _mailbox.removeAt(i);
    wallet.addCoins(g.coins);
    wallet.addGems(g.gems);
    _persistMailbox();
    notifyListeners();
  }

  void claimAll(WalletService wallet) {
    for (final g in _mailbox) {
      wallet.addCoins(g.coins);
      wallet.addGems(g.gems);
    }
    _mailbox.clear();
    _persistMailbox();
    notifyListeners();
  }

  void _addGift(String title, int coins, int gems) {
    _mailbox.add(Gift(++_giftSeq, title, coins, gems));
    _persistMailbox();
  }

  void _persistMailbox() {
    _prefs
      ..setString(
          _kMailbox, jsonEncode(_mailbox.map((g) => g.toJson()).toList()))
      ..setInt(_kGiftSeq, _giftSeq);
  }

  /// Mint a mailbox reward for every level gained since last seen.
  void syncLevelRewards(WalletService wallet) {
    final last = _prefs.getInt(_kLastLevel) ?? 1;
    var changed = false;
    for (var lvl = last + 1; lvl <= wallet.level; lvl++) {
      _addGift('Level $lvl reward', lvl * 500, lvl % 5 == 0 ? 1 : 0);
      changed = true;
    }
    if (wallet.level != last) _prefs.setInt(_kLastLevel, wallet.level);
    if (changed) notifyListeners();
  }
}
