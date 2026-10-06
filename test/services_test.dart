import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slots/services/engagement_service.dart';
import 'package:slots/services/jackpot_service.dart';
import 'package:slots/services/wallet_service.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('WalletService economy', () {
    test('recordSpin tracks stats and scales XP with the bet', () async {
      final w = WalletService();
      await w.load();
      final xp0 = w.xp;

      w.recordSpin(bet: 100, win: 250);
      expect(w.totalSpins, 1);
      expect(w.totalWagered, 100);
      expect(w.totalWon, 250);
      expect(w.biggestWin, 250);
      expect(w.xp, xp0 + 50); // bet ~/ 2

      w.recordSpin(bet: 100, win: 40);
      expect(w.totalSpins, 2);
      expect(w.biggestWin, 250); // smaller win doesn't lower it
      expect(w.totalWon, 290);
    });

    test('spendGems and exchangeGemsForCoins respect balance', () async {
      final w = WalletService();
      await w.load();
      final gems0 = w.gems; // 10
      final coins0 = w.coins;

      expect(w.spendGems(gems0 + 1), isFalse); // can't overspend
      expect(w.gems, gems0);

      final credited = w.exchangeGemsForCoins(5);
      expect(credited, 5 * WalletService.gemToCoinRate);
      expect(w.gems, gems0 - 5);
      expect(w.coins, coins0 + credited);

      expect(w.exchangeGemsForCoins(999), 0); // not enough → no-op
    });

    test('VIP tier climbs with total wagered', () async {
      final w = WalletService();
      await w.load();
      expect(w.vipTierIndex, 0); // NOVA ROOKIE at 0 wager

      // 50 vip points = 50 * 1000 wagered → STAR CADET (index 1).
      w.recordSpin(bet: 50 * WalletService.vipPointPerWager, win: 0);
      expect(w.vipTierIndex, greaterThanOrEqualTo(1));
      expect(w.vipTier.name, isNotEmpty);
    });

    test('persistence survives reload', () async {
      final w = WalletService();
      await w.load();
      w.recordSpin(bet: 200, win: 1000);
      final w2 = WalletService();
      await w2.load();
      expect(w2.totalSpins, 1);
      expect(w2.biggestWin, 1000);
    });
  });

  group('JackpotService', () {
    test('contribute grows pools; award pays pool and resets to seed', () async {
      final jp = JackpotService();
      await jp.load();
      final miniSeed = JackpotService.seeds[JackpotTier.mini]!;
      expect(jp.value(JackpotTier.mini), miniSeed);

      jp.contribute(100000);
      expect(jp.value(JackpotTier.mini), greaterThan(miniSeed));

      final grown = jp.value(JackpotTier.mini);
      final won = jp.award(JackpotTier.mini);
      expect(won, grown);
      expect(jp.value(JackpotTier.mini), miniSeed); // reset
    });

    test('pools persist across reload', () async {
      final jp = JackpotService();
      await jp.load();
      jp.contribute(500000);
      final grand = jp.value(JackpotTier.grand);
      final jp2 = JackpotService();
      await jp2.load();
      expect(jp2.value(JackpotTier.grand), grand);
    });
  });

  group('EngagementService wheel + faucets', () {
    test('wheel spins once per day and grants its prize', () async {
      final w = WalletService();
      await w.load();
      final eng = EngagementService();
      await eng.load(w);

      expect(eng.canSpinWheel, isTrue);
      final before = w.coins + w.gems;
      final result = eng.spinDailyWheel(w, rng: Random(1));
      expect(result, isNotNull);
      expect(w.coins + w.gems, greaterThan(before));
      expect(eng.canSpinWheel, isFalse);
      expect(eng.spinDailyWheel(w), isNull); // locked same day
    });

    test('store pack + flash deal gate once per day; flash costs gems',
        () async {
      final w = WalletService();
      await w.load();
      final eng = EngagementService();
      await eng.load(w);

      expect(eng.canClaimStorePack, isTrue);
      expect(eng.claimStorePack(w), isTrue);
      expect(eng.canClaimStorePack, isFalse);
      expect(eng.claimStorePack(w), isFalse);

      // Flash deal needs enough gems and locks after purchase.
      w.addGems(EngagementService.flashDealGemCost);
      final gemsBefore = w.gems;
      expect(eng.claimFlashDeal(w), isTrue);
      expect(w.gems,
          gemsBefore - EngagementService.flashDealGemCost + EngagementService.flashDealGems);
      expect(eng.canClaimFlashDeal, isFalse);
    });
  });

  group('EngagementService missions', () {
    test('progress accrues and a completed mission can be claimed', () async {
      final w = WalletService();
      await w.load();
      final eng = EngagementService();
      await eng.load(w);

      expect(eng.missions.length, EngagementService.missionSlots);

      // Drive every mission type far past its target.
      eng.recordSpins(100);
      eng.recordWinCoins(1000000);
      eng.recordBigWin();
      eng.recordBigWin();
      eng.recordBigWin();
      eng.recordGameOpened('a');
      eng.recordGameOpened('b');
      eng.recordGameOpened('c');

      final claimable = eng.missions.where((m) => m.claimable).toList();
      expect(claimable, isNotEmpty);

      final coins0 = w.coins;
      final m = claimable.first;
      expect(eng.claimMission(w, m.slot), isTrue);
      expect(w.coins, greaterThan(coins0));
      expect(eng.claimMission(w, m.slot), isFalse); // can't double-claim
    });
  });
}
