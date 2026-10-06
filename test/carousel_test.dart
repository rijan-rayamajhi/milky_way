import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slots/models/slot_game.dart';
import 'package:slots/screens/lobby_screen.dart';
import 'package:slots/services/engagement_service.dart';
import 'package:slots/services/jackpot_service.dart';
import 'package:slots/services/wallet_service.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Featured carousel renders PageView and responds to swipe',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final wallet = WalletService();
    await wallet.load();
    final engagement = EngagementService();
    await engagement.load(wallet);
    final jackpots = JackpotService();

    await tester.pumpWidget(
      MaterialApp(
        home: LobbyScreen(
          wallet: wallet,
          engagement: engagement,
          jackpots: jackpots,
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));

    // Verify PageView exists
    final pageView = find.byType(PageView);
    expect(pageView, findsOneWidget);

    // Initial game should be the first game inside PageView
    expect(
      find.descendant(of: pageView, matching: find.text(kGames[0].name)),
      findsOneWidget,
    );

    // Swipe left to navigate to the next featured game
    await tester.drag(pageView, const Offset(-400, 0));
    await tester.pump(const Duration(milliseconds: 500));

    // Now the second game should be visible inside PageView
    expect(
      find.descendant(of: pageView, matching: find.text(kGames[1].name)),
      findsOneWidget,
    );
  });
}
