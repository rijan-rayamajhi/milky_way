import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/lobby_screen.dart';
import 'services/wallet_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final wallet = WalletService();
  await wallet.load();
  runApp(MilkyWayApp(wallet: wallet));
}

class MilkyWayApp extends StatelessWidget {
  final WalletService wallet;
  const MilkyWayApp({super.key, required this.wallet});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Milky Way',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: LobbyScreen(wallet: wallet),
    );
  }
}
