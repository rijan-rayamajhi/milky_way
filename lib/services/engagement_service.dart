import 'dart:convert';
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

/// All offline, timestamp-based retention mechanics:
/// 7-day daily streak, hourly free coins, and a mailbox of gifts.
class EngagementService extends ChangeNotifier {
  static const _kStreakDate = 'streak_date';
  static const _kStreakDay = 'streak_day';
  static const _kHourly = 'hourly_last';
  static const _kMailbox = 'mailbox';
  static const _kGiftSeq = 'gift_seq';
  static const _kLastLevel = 'last_level';

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

  late SharedPreferences _prefs;
  String _streakDate = '';
  int _streakDay = 0;
  int _hourlyLast = 0;
  int _giftSeq = 0;
  List<Gift> _mailbox = [];

  List<Gift> get mailbox => List.unmodifiable(_mailbox);
  int get unreadCount => _mailbox.length;

  Future<void> load(WalletService wallet) async {
    _prefs = await SharedPreferences.getInstance();
    _streakDate = _prefs.getString(_kStreakDate) ?? '';
    _streakDay = _prefs.getInt(_kStreakDay) ?? 0;
    _hourlyLast = _prefs.getInt(_kHourly) ?? 0;
    _giftSeq = _prefs.getInt(_kGiftSeq) ?? 0;
    _mailbox = (jsonDecode(_prefs.getString(_kMailbox) ?? '[]') as List)
        .map((e) => Gift.fromJson(e as Map<String, dynamic>))
        .toList();
    syncLevelRewards(wallet);
    notifyListeners();
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

  // ---- Hourly free coins ----

  bool get canClaimHourly =>
      DateTime.now().millisecondsSinceEpoch - _hourlyLast >=
      hourlyCooldown.inMilliseconds;

  Duration get hourlyRemaining {
    final elapsed =
        DateTime.now().millisecondsSinceEpoch - _hourlyLast;
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

  // ---- Mailbox ----

  void _addGift(String title, int coins, int gems) {
    _mailbox.add(Gift(++_giftSeq, title, coins, gems));
    _persistMailbox();
  }

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

  void _persistMailbox() {
    _prefs
      ..setString(_kMailbox, jsonEncode(_mailbox.map((g) => g.toJson()).toList()))
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
