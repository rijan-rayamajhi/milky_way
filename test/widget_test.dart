import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slots/services/wallet_service.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('wallet: spend, rescue, and level progression', () async {
    final w = WalletService();
    await w.load();

    // starts with defaults
    expect(w.coins, WalletService.startingCoins);
    expect(w.level, 1);

    // can't overspend
    expect(w.spendCoins(WalletService.startingCoins + 1), isFalse);
    // valid spend
    expect(w.spendCoins(1000), isTrue);
    expect(w.coins, WalletService.startingCoins - 1000);

    // rescue only fires when broke
    w.spendCoins(w.coins);
    expect(w.isBroke, isTrue);
    w.grantRescue();
    expect(w.coins, WalletService.rescueAmount);

    // XP crosses a level boundary
    w.addXp(WalletService.xpPerLevel);
    expect(w.level, 2);
  });
}
