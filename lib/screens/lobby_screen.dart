import 'dart:async';
import 'package:flutter/material.dart';
import '../models/slot_game.dart';
import '../services/wallet_service.dart';
import '../theme/app_theme.dart';
import '../widgets/cosmic_button.dart';
import '../widgets/currency_bar.dart';
import '../widgets/game_tile.dart';
import 'game_screen.dart';

class LobbyScreen extends StatefulWidget {
  final WalletService wallet;
  const LobbyScreen({super.key, required this.wallet});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  int _navIndex = 0;
  int _featured = 0;
  Timer? _rotator;

  @override
  void initState() {
    super.initState();
    // Rotate the featured banner through the games.
    _rotator = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) setState(() => _featured = (_featured + 1) % kGames.length);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeRescue());
  }

  @override
  void dispose() {
    _rotator?.cancel();
    super.dispose();
  }

  void _maybeRescue() {
    if (!widget.wallet.isBroke) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _rewardDialog(
        title: 'Out of Coins!',
        asset: 'assets/images/engagement/reward_chest.png',
        message: 'Here\'s a rescue bonus to keep you playing.',
        cta: 'Collect ${WalletService.rescueAmount}',
        onCollect: () {
          widget.wallet.grantRescue();
          Navigator.pop(context);
        },
      ),
    );
  }

  void _openGame(SlotGame g) {
    if (!g.unlockedAt(widget.wallet.level)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reach Level ${g.unlockLevel} to unlock ${g.name}')),
      );
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => GameScreen(game: g)));
  }

  void _dailyWheel() {
    // Demo grant; the real daily/variable wheel is Phase 3 (EngagementService).
    showDialog(
      context: context,
      builder: (_) => _rewardDialog(
        title: 'Daily Bonus',
        asset: 'assets/images/engagement/daily_wheel.png',
        message: 'Spin once a day for free coins and gems!',
        cta: 'Collect 2,000',
        onCollect: () {
          widget.wallet.addCoins(2000);
          widget.wallet.addGems(1);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _getCoins() {
    showDialog(
      context: context,
      builder: (_) => _rewardDialog(
        title: 'Get Coins',
        asset: 'assets/images/engagement/reward_chest.png',
        message: 'Coin store arrives soon. Here\'s a starter pack!',
        cta: 'Collect 5,000',
        onCollect: () {
          widget.wallet.addCoins(5000);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/lobby/lobby_background.png', fit: BoxFit.cover),
          Container(color: AppColors.navy.withValues(alpha: 0.25)),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: CurrencyBar(wallet: widget.wallet, onGetCoins: _getCoins),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      Center(
                        child: Image.asset('assets/images/branding/logo.png',
                            height: 92),
                      ),
                      const SizedBox(height: 8),
                      _featuredBanner(),
                      const SizedBox(height: 16),
                      _dailyButton(),
                      const SizedBox(height: 18),
                      _gameGrid(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _bottomNav(),
    );
  }

  Widget _featuredBanner() {
    final g = kGames[_featured];
    return AspectRatio(
      aspectRatio: 1080 / 480,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Image.asset(g.asset,
                        key: ValueKey(g.id), fit: BoxFit.contain),
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('FEATURED',
                          style: TextStyle(
                              color: AppColors.teal,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              letterSpacing: 2)),
                      Text(g.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18)),
                      const SizedBox(height: 10),
                      CosmicButton(
                        label: 'PLAY',
                        icon: Icons.play_arrow_rounded,
                        height: 42,
                        onTap: () => _openGame(g),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          IgnorePointer(
            child: Image.asset('assets/images/lobby/featured_frame.png',
                fit: BoxFit.fill),
          ),
        ],
      ),
    );
  }

  Widget _dailyButton() {
    return Row(
      children: [
        Image.asset('assets/images/engagement/daily_wheel.png', width: 56),
        const SizedBox(width: 12),
        Expanded(
          child: CosmicButton(
            label: 'DAILY BONUS',
            icon: Icons.card_giftcard,
            gradient: const LinearGradient(
                colors: [AppColors.magenta, AppColors.purple]),
            onTap: _dailyWheel,
          ),
        ),
      ],
    );
  }

  Widget _gameGrid() {
    return ListenableBuilder(
      listenable: widget.wallet,
      builder: (context, _) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: kGames.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 0.82,
        ),
        itemBuilder: (context, i) {
          final g = kGames[i];
          return GameTile(
            game: g,
            unlocked: g.unlockedAt(widget.wallet.level),
            onTap: () => _openGame(g),
          );
        },
      ),
    );
  }

  Widget _bottomNav() {
    const items = [
      (Icons.home_rounded, 'Lobby'),
      (Icons.storefront_rounded, 'Store'),
      (Icons.mail_rounded, 'Mailbox'),
      (Icons.calendar_today_rounded, 'Daily'),
      (Icons.person_rounded, 'Profile'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.deepPurple,
        border: Border(top: BorderSide(color: AppColors.gold.withValues(alpha: 0.4))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (int i = 0; i < items.length; i++)
              _navItem(items[i].$1, items[i].$2, i),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int i) {
    final active = _navIndex == i;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() => _navIndex = i);
        if (i == 3) {
          _dailyWheel();
        } else if (i != 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$label — coming soon')),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: active ? AppColors.gold : AppColors.textDim, size: 26),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    color: active ? AppColors.gold : AppColors.textDim,
                    fontSize: 10,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
          ],
        ),
      ),
    );
  }

  Widget _rewardDialog({
    required String title,
    required String asset,
    required String message,
    required String cta,
    required VoidCallback onCollect,
  }) {
    return Dialog(
      backgroundColor: AppColors.deepPurple,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.gold.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Image.asset(asset, width: 120),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 18),
            CosmicButton(label: cta, width: double.infinity, onTap: onCollect),
          ],
        ),
      ),
    );
  }
}
