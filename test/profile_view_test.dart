import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slots/services/engagement_service.dart';
import 'package:slots/services/sound_service.dart';
import 'package:slots/services/wallet_service.dart';
import 'package:slots/widgets/cosmic_profile_view.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('CosmicProfileView renders stats and handles audio/recharge interactions',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final wallet = WalletService();
    await wallet.load();
    final eng = EngagementService();
    await eng.load(wallet);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CosmicProfileView(wallet: wallet, engagement: eng),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Verify key titles and components
    expect(find.text('COMMANDER DOSSIER'), findsOneWidget);
    expect(find.text('Cosmic Commander'), findsOneWidget);
    expect(find.text('CAREER TROPHY MATRIX'), findsOneWidget);
    expect(find.text('VIP CLUB STATUS & PERKS'), findsOneWidget);
    expect(find.text('AUDIO & HAPTIC CONSOLE'), findsOneWidget);
    // Real achievements card replaced the dev testing/faucet console.
    expect(find.text('ACHIEVEMENTS'), findsOneWidget);
    expect(find.text('BIGGEST WIN'), findsOneWidget);
    expect(find.text('TOTAL SPINS'), findsOneWidget);

    // Three independent toggles: music, sound FX, haptics.
    expect(sound.musicEnabled, isTrue);
    expect(sound.sfxEnabled, isTrue);
    expect(sound.hapticsEnabled, isTrue);
    expect(find.text('ACTIVE'), findsOneWidget);
    final switches = find.byType(Switch);
    expect(switches, findsNWidgets(3));

    // Turn all three off → badge reads MUTED.
    for (var i = 0; i < 3; i++) {
      await tester.tap(switches.at(i));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(sound.musicEnabled, isFalse);
    expect(sound.sfxEnabled, isFalse);
    expect(sound.hapticsEnabled, isFalse);
    expect(find.text('MUTED'), findsOneWidget);

    // Re-enable all three.
    for (var i = 0; i < 3; i++) {
      await tester.tap(switches.at(i));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(sound.musicEnabled, isTrue);
    expect(sound.sfxEnabled, isTrue);
    expect(sound.hapticsEnabled, isTrue);

    // Flush any pending toast timers
    await tester.pump(const Duration(seconds: 4));
  });
}
