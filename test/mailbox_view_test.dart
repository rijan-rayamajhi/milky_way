import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slots/services/engagement_service.dart';
import 'package:slots/services/wallet_service.dart';
import 'package:slots/widgets/cosmic_mailbox_view.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('CosmicMailboxView renders empty state and handles simulated airdrop',
      (tester) async {
    final wallet = WalletService();
    await wallet.load();
    final eng = EngagementService();
    await eng.load(wallet);

    var navigatedToLobby = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CosmicMailboxView(
            wallet: wallet,
            engagement: eng,
            onGoToLobby: () => navigatedToLobby = true,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Empty state should be visible
    expect(find.text('COSMIC INBOX'), findsOneWidget);
    expect(find.text('Your Inbox is Clear'), findsOneWidget);
    expect(find.text('NEXT AIRDROP RADAR'), findsOneWidget);
    expect(find.text('SPIN SLOTS NOW'), findsOneWidget);

    // Tap SPIN SLOTS NOW CTA
    await tester.tap(find.text('SPIN SLOTS NOW'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(navigatedToLobby, isTrue);

    // Ensure debug Orbital Test Beacon is NOT present in production UI
    expect(find.text('ORBITAL TEST BEACON'), findsNothing);
    expect(find.text('+SEND GIFT'), findsNothing);

    // Trigger an airdrop via level-up rewards
    wallet.addXp(1000);
    eng.syncLevelRewards(wallet);
    await tester.pump(const Duration(milliseconds: 200));

    // Verify gift is now present in the mailbox list
    expect(find.text('CLAIM'), findsOneWidget);
    expect(find.text('LEVEL REWARD'), findsOneWidget);

    // Claim the gift
    final startCoins = wallet.coins;
    await tester.tap(find.text('CLAIM'));
    await tester.pump(const Duration(milliseconds: 350));

    // Unboxing modal shown
    expect(find.text('AIRDROP SECURED!'), findsOneWidget);
    expect(wallet.coins, greaterThan(startCoins));

    // Dismiss modal
    await tester.tap(find.text('COLLECT & CONTINUE'));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('AIRDROP SECURED!'), findsNothing);
  });
}
