import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slots/services/engagement_service.dart';
import 'package:slots/services/wallet_service.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('daily, hourly, and level-reward mailbox', () async {
    final wallet = WalletService();
    await wallet.load();
    final eng = EngagementService();
    await eng.load(wallet);

    // Daily: claimable once, then locked for the day.
    expect(eng.canClaimDaily, isTrue);
    expect(eng.nextStreakDay, 1);
    final before = wallet.coins;
    final r = eng.claimDaily(wallet)!;
    expect(wallet.coins, before + r.coins);
    expect(eng.canClaimDaily, isFalse);
    expect(eng.claimDaily(wallet), isNull);

    // Hourly: available from a fresh install, then on cooldown.
    expect(eng.canClaimHourly, isTrue);
    final c2 = wallet.coins;
    expect(eng.claimHourly(wallet), isTrue);
    expect(wallet.coins, c2 + EngagementService.hourlyCoins);
    expect(eng.canClaimHourly, isFalse);

    // Level up → mailbox gift minted, claimable.
    wallet.addXp(WalletService.xpPerLevel); // now level 2
    eng.syncLevelRewards(wallet);
    expect(eng.unreadCount, 1);
    final c3 = wallet.coins;
    eng.claimAll(wallet);
    expect(eng.unreadCount, 0);
    expect(wallet.coins, greaterThan(c3));
  });
}
