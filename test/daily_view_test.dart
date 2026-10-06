import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slots/services/engagement_service.dart';
import 'package:slots/services/wallet_service.dart';
import 'package:slots/widgets/cosmic_daily_view.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('CosmicDailyView renders and spins lucky wheel', (tester) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final wallet = WalletService();
    await wallet.load();
    final eng = EngagementService();
    await eng.load(wallet);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CosmicDailyView(wallet: wallet, engagement: eng),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Verify key titles and components
    expect(find.text('DAILY REWARDS'), findsOneWidget);
    expect(find.text('LUCKY SPIN WHEEL'), findsOneWidget);
    expect(find.text('HOURLY STAR DROP'), findsOneWidget);
    expect(find.text('7-DAY STREAK LADDER'), findsOneWidget);
    expect(find.text('APEX COSMIC VAULT'), findsOneWidget);

    // Daily missions section is present.
    expect(find.text('DAILY MISSIONS'), findsOneWidget);

    // Initial wheel state
    expect(eng.canSpinWheel, isTrue);
    expect(find.text('SPIN LUCKY WHEEL'), findsOneWidget);

    // Spin the lucky wheel — the prize is random (coins and/or gems), so assert
    // on total value gained rather than coins alone.
    final startValue = wallet.coins + wallet.gems;
    await tester.tap(find.text('SPIN LUCKY WHEEL'));
    await tester.pump(); // start animation
    await tester.pump(const Duration(milliseconds: 3300)); // finish wheel duration
    await tester.pump(); // flush completion microtask
    await tester.pump(const Duration(milliseconds: 400)); // modal transition

    // Celebration modal appears and something was awarded.
    expect(find.text('WHEEL PRIZE!'), findsOneWidget);
    expect(wallet.coins + wallet.gems, greaterThan(startValue));
    expect(eng.canSpinWheel, isFalse);

    // Dismiss celebration modal
    await tester.tap(find.text('COLLECT & PLAY'), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('WHEEL PRIZE!'), findsNothing);
  });
}
