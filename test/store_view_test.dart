import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slots/services/engagement_service.dart';
import 'package:slots/services/wallet_service.dart';
import 'package:slots/widgets/cosmic_store_view.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('CosmicStoreView renders and allows filtering', (tester) async {
    final wallet = WalletService();
    await wallet.load();
    final eng = EngagementService();
    await eng.load(wallet);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CosmicStoreView(wallet: wallet, engagement: eng),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Header and titles
    expect(find.text('COSMIC TREASURY'), findsOneWidget);
    expect(find.text('SUPERNOVA BUNDLE'), findsOneWidget);
    expect(find.text('Cosmic Explorer Kit'), findsOneWidget);

    // Tap GEMS category filter
    await tester.tap(find.text('GEMS').first);
    await tester.pump(const Duration(milliseconds: 250));

    // Verify Gem packs visible
    expect(find.text('Starlight Shards'), findsOneWidget);
    expect(find.text('Crown Diamond'), findsOneWidget);

    // Tap ALL category filter
    await tester.tap(find.text('ALL'));
    await tester.pump(const Duration(milliseconds: 250));

    // Claim daily free pack
    final startCoins = wallet.coins;
    expect(find.text('FREE'), findsOneWidget);
    await tester.tap(find.text('FREE'));
    await tester.pump(const Duration(milliseconds: 350));

    // Dialog pops up
    expect(find.text('EXPLORER KIT OPENED!'), findsOneWidget);
    expect(wallet.coins, startCoins + 10000);

    // Dismiss dialog
    await tester.tap(find.text('COLLECT & PLAY'));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('EXPLORER KIT OPENED!'), findsNothing);
  });
}
