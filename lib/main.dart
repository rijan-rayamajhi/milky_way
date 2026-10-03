import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/lobby_screen.dart';
import 'services/engagement_service.dart';
import 'services/wallet_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final wallet = WalletService();
  await wallet.load();
  final engagement = EngagementService();
  await engagement.load(wallet);
  runApp(MilkyWayApp(wallet: wallet, engagement: engagement));
}

class MilkyWayApp extends StatelessWidget {
  final WalletService wallet;
  final EngagementService engagement;
  const MilkyWayApp(
      {super.key, required this.wallet, required this.engagement});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Milky Way',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: LobbyScreen(wallet: wallet, engagement: engagement),
    );
  }
}
