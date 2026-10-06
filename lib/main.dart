import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/lobby_screen.dart';
import 'services/engagement_service.dart';
import 'services/jackpot_service.dart';
import 'services/sound_service.dart';
import 'services/wallet_service.dart';
import 'theme/app_theme.dart';

import 'widgets/coin_fly_overlay.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await sound.load();
  sound.startMusic();
  final wallet = WalletService();
  await wallet.load();
  final engagement = EngagementService();
  await engagement.load(wallet);
  final jackpots = JackpotService();
  await jackpots.load();
  runApp(MilkyWayApp(
      wallet: wallet, engagement: engagement, jackpots: jackpots));
}

class MilkyWayApp extends StatelessWidget {
  final WalletService wallet;
  final EngagementService engagement;
  final JackpotService jackpots;
  const MilkyWayApp(
      {super.key,
      required this.wallet,
      required this.engagement,
      required this.jackpots});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Milky Way',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      builder: (context, child) => CoinFlyOverlay(
        wallet: wallet,
        child: child ?? const SizedBox.shrink(),
      ),
      home: LobbyScreen(
          wallet: wallet, engagement: engagement, jackpots: jackpots),
    );
  }
}
