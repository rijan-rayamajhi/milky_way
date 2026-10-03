import 'dart:async';
import 'package:flutter/material.dart';
import '../models/slot_game.dart';
import '../services/engagement_service.dart';
import '../services/sound_service.dart';
import '../services/wallet_service.dart';
import '../theme/app_theme.dart';
import '../widgets/cosmic_button.dart';
import '../widgets/currency_bar.dart';
import '../widgets/daily_dialog.dart';
import '../widgets/game_tile.dart';
import '../widgets/slot_machine.dart';
import '../games/cosmic_fortune_config.dart';
import '../games/ways_configs.dart';
import '../games/hold_win_screen.dart';
import '../widgets/game_bottom_nav_bar.dart';
import 'mailbox_screen.dart';

class LobbyScreen extends StatefulWidget {
  final WalletService wallet;
  final EngagementService engagement;
  const LobbyScreen(
      {super.key, required this.wallet, required this.engagement});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  int _navIndex = 0;
  int _featured = 0;
  Timer? _rotator;
  Timer? _ticker; // refreshes the hourly countdown

  EngagementService get eng => widget.engagement;

  @override
  void initState() {
    super.initState();
    // Rotate the featured banner through the games.
    _rotator = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) setState(() => _featured = (_featured + 1) % kGames.length);
    });
    // Tick once a second so the hourly timer counts down live.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeRescue());
  }

  @override
  void dispose() {
    _rotator?.cancel();
    _ticker?.cancel();
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

  Future<void> _openGame(SlotGame g) async {
    if (!g.unlockedAt(widget.wallet.level)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reach Level ${g.unlockLevel} to unlock ${g.name}')),
      );
      return;
    }
    final w = widget.wallet;
    final Widget screen = switch (g.id) {
      'cosmic_fortune' =>
        SlotMachine(title: g.name, config: cosmicFortuneConfig, wallet: w),
      'galaxy_gold' => HoldWinScreen(title: g.name, wallet: w),
      'starburst_nova' => SlotMachine(
          title: g.name,
          config: starburstNovaConfig,
          wallet: w,
          expandingWild: true),
      'lucky_nebula' => SlotMachine(
          title: g.name,
          config: luckyNebulaConfig,
          wallet: w,
          cascades: true),
      'asteroid_blitz' => SlotMachine(
          title: g.name,
          config: asteroidBlitzConfig,
          wallet: w,
          stickyWildSpins: 3),
      _ => SlotMachine(title: g.name, config: cosmicFortuneConfig, wallet: w),
    };
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    // Playing may have leveled the player up → mint any level-reward gifts.
    eng.syncLevelRewards(widget.wallet);
  }

  Future<void> _openDaily() async {
    await showDailyBonus(context, eng, widget.wallet);
    if (mounted) setState(() => _navIndex = 0);
  }

  Future<void> _openMailbox() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MailboxScreen(eng: eng, wallet: widget.wallet),
      ),
    );
    if (mounted) setState(() => _navIndex = 0);
  }

  Future<void> _openSettings() async {
    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
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
              const Text('Settings',
                  style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              ListenableBuilder(
                listenable: sound,
                builder: (context, _) => SwitchListTile(
                  title: const Text('Sound & Haptics',
                      style: TextStyle(color: Colors.white)),
                  activeThumbColor: AppColors.gold,
                  value: sound.enabled,
                  onChanged: (v) => sound.setEnabled(v),
                ),
              ),
              Text('Level ${widget.wallet.level}',
                  style: const TextStyle(color: AppColors.textDim)),
            ],
          ),
        ),
      ),
    );
  }

  void _claimHourly() {
    if (eng.claimHourly(widget.wallet)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🪙 +1,000 free coins!')),
      );
    }
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
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/lobby/lobby_background.png', fit: BoxFit.cover),
          Container(color: AppColors.navy.withValues(alpha: 0.25)),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: CurrencyBar(wallet: widget.wallet, onGetCoins: _getCoins),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
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
    return ListenableBuilder(
      listenable: eng,
      builder: (context, _) => Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Image.asset('assets/images/engagement/daily_wheel.png', width: 56),
              if (eng.canClaimDaily)
                const Positioned(right: -2, top: -2, child: _ReadyDot()),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: CosmicButton(
              label: 'DAILY BONUS',
              icon: Icons.card_giftcard,
              gradient: const LinearGradient(
                  colors: [AppColors.magenta, AppColors.purple]),
              onTap: _openDaily,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: CosmicButton(
              label: eng.canClaimHourly
                  ? 'FREE'
                  : _fmtDuration(eng.hourlyRemaining),
              icon: eng.canClaimHourly ? Icons.add_circle : Icons.timer,
              height: 54,
              gradient: const LinearGradient(
                  colors: [AppColors.teal, AppColors.purple]),
              onTap: eng.canClaimHourly ? _claimHourly : null,
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
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
    return ListenableBuilder(
      listenable: eng,
      builder: (context, _) => GameBottomNavBar(
        selectedIndex: _navIndex,
        unreadMailCount: eng.unreadCount,
        canClaimDaily: eng.canClaimDaily,
        onTabSelected: (i) async {
          setState(() => _navIndex = i);
          switch (i) {
            case 0:
              break;
            case 1:
              _getCoins();
              if (mounted) setState(() => _navIndex = 0);
              break;
            case 2:
              await _openMailbox();
              break;
            case 3:
              await _openDaily();
              break;
            case 4:
              await _openSettings();
              if (mounted) setState(() => _navIndex = 0);
              break;
          }
        },
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

/// Small pulsing "ready to claim" indicator.
class _ReadyDot extends StatelessWidget {
  const _ReadyDot();
  @override
  Widget build(BuildContext context) => Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: AppColors.magenta,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(color: AppColors.magenta.withValues(alpha: 0.8), blurRadius: 6),
          ],
        ),
      );
}
