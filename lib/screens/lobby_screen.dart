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

  void _openDaily() => showDailyBonus(context, eng, widget.wallet);

  void _claimHourly() {
    if (eng.claimHourly(widget.wallet)) {
      sound.win();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🪙 +1,000 free coins claimed!')),
      );
    }
  }

  void _getCoins() => setState(() => _navIndex = 1);

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
                  child: IndexedStack(
                    index: _navIndex,
                    children: [
                      _lobbyView(),
                      _storeView(),
                      _mailboxView(),
                      _dailyView(),
                      _profileView(),
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

  // -------------------------------------------------------------
  // TAB 0: LOBBY
  // -------------------------------------------------------------
  Widget _lobbyView() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      children: [
        Center(
          child: Image.asset('assets/images/branding/logo.png', height: 92),
        ),
        const SizedBox(height: 8),
        _featuredBanner(),
        const SizedBox(height: 16),
        _dailyButton(),
        const SizedBox(height: 18),
        _gameGrid(),
      ],
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
          GestureDetector(
            onTap: _openDaily,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Image.asset('assets/images/engagement/daily_wheel.png', width: 56),
                if (eng.canClaimDaily)
                  const Positioned(right: -2, top: -2, child: _ReadyDot()),
              ],
            ),
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

  // -------------------------------------------------------------
  // TAB 1: STORE
  // -------------------------------------------------------------
  Widget _storeView() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
      children: [
        _tabHeader(
          'COSMIC TREASURY',
          'Instant Coin Packs & Starlight Gem Vaults',
          Icons.storefront_rounded,
        ),
        const SizedBox(height: 14),
        // Starter Pack
        _storeStarterCard(),
        const SizedBox(height: 20),
        _sectionTitle('COIN VAULTS', Icons.monetization_on_rounded),
        const SizedBox(height: 10),
        _storePackCard(
          title: 'Nebula Pouch',
          asset: 'assets/images/currency/coin.png',
          amount: '+25,000 Coins',
          badge: 'POPULAR',
          badgeColor: AppColors.teal,
          cta: 'GET 25K',
          onCollect: () {
            widget.wallet.addCoins(25000);
            sound.win();
            _notify('🪙 +25,000 Coins added to your vault!');
          },
        ),
        const SizedBox(height: 10),
        _storePackCard(
          title: 'Supernova Stash',
          asset: 'assets/images/currency/coin.png',
          amount: '+100,000 Coins · +10 Gems',
          badge: 'HOT DEAL',
          badgeColor: AppColors.magenta,
          cta: 'GET 100K',
          onCollect: () {
            widget.wallet.addCoins(100000);
            widget.wallet.addGems(10);
            sound.bigWin();
            _notify('🌟 +100,000 Coins & 10 Gems collected!');
          },
        ),
        const SizedBox(height: 10),
        _storePackCard(
          title: 'Galactic Treasury',
          asset: 'assets/images/currency/coin.png',
          amount: '+500,000 Coins · +50 Gems',
          badge: 'BEST VALUE',
          badgeColor: AppColors.gold,
          cta: 'GET 500K',
          onCollect: () {
            widget.wallet.addCoins(500000);
            widget.wallet.addGems(50);
            sound.bigWin();
            _notify('👑 JACKPOT! +500,000 Coins & 50 Gems added!');
          },
        ),
        const SizedBox(height: 20),
        _sectionTitle('GEM CACHE', Icons.diamond_rounded),
        const SizedBox(height: 10),
        _storePackCard(
          title: 'Starlight Shards',
          asset: 'assets/images/currency/gem.png',
          amount: '+50 Cosmic Gems',
          badge: 'GEMS',
          badgeColor: AppColors.teal,
          cta: 'GET 50',
          onCollect: () {
            widget.wallet.addGems(50);
            sound.win();
            _notify('💎 +50 Gems delivered!');
          },
        ),
        const SizedBox(height: 10),
        _storePackCard(
          title: 'Crown Diamond Cache',
          asset: 'assets/images/currency/gem.png',
          amount: '+250 Cosmic Gems',
          badge: 'MEGA PACK',
          badgeColor: AppColors.gold,
          cta: 'GET 250',
          onCollect: () {
            widget.wallet.addGems(250);
            sound.bigWin();
            _notify('💎 +250 Gems added to your inventory!');
          },
        ),
      ],
    );
  }

  Widget _storeStarterCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF351268), Color(0xFF170835)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gold, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.25),
            blurRadius: 14,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Image.asset('assets/images/engagement/reward_chest.png', width: 54),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: AppColors.magenta,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('FREE PACK',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900)),
                ),
                const SizedBox(height: 3),
                const Text('Cosmic Explorer Kit',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14)),
                const SizedBox(height: 2),
                const Text('+10,000 Coins · +5 Gems',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AppColors.gold,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          CosmicButton(
            label: 'FREE',
            height: 38,
            width: 76,
            fontSize: 12,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            onTap: () {
              widget.wallet.addCoins(10000);
              widget.wallet.addGems(5);
              sound.win();
              _notify('✨ Explorer Kit: 10,000 Coins & 5 Gems claimed!');
            },
          ),
        ],
      ),
    );
  }

  Widget _storePackCard({
    required String title,
    required String asset,
    required String amount,
    required String badge,
    required Color badgeColor,
    required String cta,
    required VoidCallback onCollect,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.deepPurple.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            offset: const Offset(0, 3),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        children: [
          Image.asset(asset, width: 42, height: 42),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: badgeColor.withValues(alpha: 0.8), width: 1),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  amount,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          CosmicButton(
            label: cta,
            height: 38,
            width: 86,
            fontSize: 12,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            onTap: onCollect,
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 2: MAILBOX
  // -------------------------------------------------------------
  Widget _mailboxView() {
    return ListenableBuilder(
      listenable: eng,
      builder: (context, _) {
        final gifts = eng.mailbox;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
          children: [
            Row(
              children: [
                Expanded(
                  child: _tabHeader(
                    'COSMIC INBOX',
                    gifts.isEmpty
                        ? 'All caught up'
                        : '${gifts.length} reward${gifts.length > 1 ? 's' : ''} waiting',
                    Icons.mark_email_unread_rounded,
                  ),
                ),
                if (gifts.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  CosmicButton(
                    label: 'CLAIM ALL',
                    height: 42,
                    onTap: () {
                      eng.claimAll(widget.wallet);
                      sound.win();
                      _notify('🎁 All mailbox rewards claimed!');
                    },
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            if (gifts.isEmpty)
              _emptyMailboxCard()
            else
              for (final g in gifts) ...[
                _giftTile(g),
                const SizedBox(height: 10),
              ],
            const SizedBox(height: 20),
            // Gift generator button for testing
            _testGiftCard(),
          ],
        );
      },
    );
  }

  Widget _giftTile(Gift g) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.deepPurple.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            offset: const Offset(0, 3),
            blurRadius: 5,
          ),
        ],
      ),
      child: Row(
        children: [
          Image.asset('assets/images/engagement/reward_chest.png', width: 42),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  g.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Image.asset('assets/images/currency/coin.png',
                        width: 16, height: 16),
                    const SizedBox(width: 4),
                    Text(
                      CurrencyBar.format(g.coins),
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    if (g.gems > 0) ...[
                      const SizedBox(width: 8),
                      Image.asset('assets/images/currency/gem.png',
                          width: 14, height: 14),
                      const SizedBox(width: 3),
                      Text(
                        '+${g.gems}',
                        style: const TextStyle(
                          color: AppColors.teal,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          CosmicButton(
            label: 'CLAIM',
            height: 36,
            width: 76,
            fontSize: 12,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            onTap: () {
              eng.claimGift(widget.wallet, g.id);
              sound.win();
              _notify('Claimed: ${g.title}');
            },
          ),
        ],
      ),
    );
  }

  Widget _emptyMailboxCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.deepPurple.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.purple.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Image.asset('assets/images/engagement/reward_chest.png', width: 84),
          const SizedBox(height: 14),
          const Text('Your Inbox is Clear',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18)),
          const SizedBox(height: 6),
          const Text(
              'Level up on any slot machine or check back daily to receive gifts!',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textDim, fontSize: 13)),
          const SizedBox(height: 18),
          CosmicButton(
            label: 'SPIN SLOTS NOW',
            icon: Icons.sports_esports_rounded,
            height: 44,
            onTap: () => setState(() => _navIndex = 0),
          ),
        ],
      ),
    );
  }

  Widget _testGiftCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.deepPurple.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: AppColors.teal, size: 22),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Simulate level gift drop',
                style: TextStyle(color: AppColors.textDim, fontSize: 12)),
          ),
          CosmicButton(
            label: '+SEND GIFT',
            height: 34,
            gradient: const LinearGradient(colors: [AppColors.teal, AppColors.purple]),
            onTap: () {
              widget.wallet.addXp(1000);
              eng.syncLevelRewards(widget.wallet);
              sound.win();
              _notify('🎁 New Level Reward arrived in your Mailbox!');
            },
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 3: DAILY
  // -------------------------------------------------------------
  Widget _dailyView() {
    return ListenableBuilder(
      listenable: eng,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
        children: [
          _tabHeader(
            'DAILY REWARDS',
            'Spin the wheel & maintain your 7-day streak',
            Icons.stars_rounded,
          ),
          const SizedBox(height: 14),
          _dailyWheelCard(),
          const SizedBox(height: 18),
          _hourlyDropCard(),
          const SizedBox(height: 18),
          _dailyStreakLadderCard(),
        ],
      ),
    );
  }

  Widget _dailyWheelCard() {
    final claimable = eng.canClaimDaily;
    final nextDay = eng.nextStreakDay;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF381268), Color(0xFF190933)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withValues(alpha: 0.4),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Image.asset('assets/images/engagement/daily_wheel.png', width: 84),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('LUCKY SPIN WHEEL',
                        style: TextStyle(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w900,
                            fontSize: 18)),
                    const SizedBox(height: 4),
                    Text(
                      claimable
                          ? '🌟 Day $nextDay reward is waiting!'
                          : 'Wheel spun for today! Return tomorrow.',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          CosmicButton(
            label: claimable ? 'SPIN LUCKY WHEEL' : 'VIEW LADDER REWARDS',
            icon: Icons.casino_rounded,
            width: double.infinity,
            height: 48,
            onTap: () => showDailyBonus(context, eng, widget.wallet),
          ),
        ],
      ),
    );
  }

  Widget _hourlyDropCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.deepPurple.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: AppColors.teal.withValues(alpha: 0.5), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.teal.withValues(alpha: 0.15),
              border: Border.all(color: AppColors.teal, width: 1.5),
            ),
            child: const Icon(Icons.timer_rounded, color: AppColors.teal, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('HOURLY STAR DROP',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  eng.canClaimHourly
                      ? '🪙 1,000 Coins ready to collect!'
                      : 'Next drop in ${_fmtDuration(eng.hourlyRemaining)}',
                  style: TextStyle(
                    color: eng.canClaimHourly ? AppColors.gold : AppColors.textDim,
                    fontSize: 13,
                    fontWeight:
                        eng.canClaimHourly ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          CosmicButton(
            label: eng.canClaimHourly ? 'CLAIM' : 'WAIT',
            height: 40,
            gradient:
                const LinearGradient(colors: [AppColors.teal, AppColors.purple]),
            onTap: eng.canClaimHourly ? _claimHourly : null,
          ),
        ],
      ),
    );
  }

  Widget _dailyStreakLadderCard() {
    final nextDay = eng.nextStreakDay;
    final claimable = eng.canClaimDaily;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.deepPurple.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('7-DAY STREAK LADDER',
              style: TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w800,
                  fontSize: 15)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.85,
            children: [
              for (final r in EngagementService.ladder)
                _dayStreakCell(r, claimable, nextDay, eng.currentStreakDay),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dayStreakCell(
      DailyReward r, bool claimable, int nextDay, int currentStreak) {
    final isToday = claimable && r.day == nextDay;
    final isClaimed = r.day < nextDay || (!claimable && r.day <= currentStreak);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: isToday
            ? AppColors.gold.withValues(alpha: 0.25)
            : AppColors.navy.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isToday
              ? AppColors.gold
              : (isClaimed ? AppColors.teal : Colors.white24),
          width: isToday ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Day ${r.day}',
              style: TextStyle(
                  color: isToday ? AppColors.gold : Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(CurrencyBar.format(r.coins),
              style: const TextStyle(
                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          if (r.gems > 0)
            Text('+${r.gems} 💎',
                style: const TextStyle(
                    color: AppColors.teal,
                    fontSize: 10,
                    fontWeight: FontWeight.w800))
          else if (isClaimed)
            const Icon(Icons.check_circle_rounded, color: AppColors.teal, size: 14),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 4: PROFILE
  // -------------------------------------------------------------
  Widget _profileView() {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.wallet, sound]),
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
        children: [
          _tabHeader(
            'COMMANDER PROFILE',
            'Account progression, economy & settings',
            Icons.person_rounded,
          ),
          const SizedBox(height: 14),
          _profilePlayerCard(),
          const SizedBox(height: 18),
          _profileSettingsCard(),
          const SizedBox(height: 18),
          _profileSandboxCard(),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'MILKY WAY CASINO · v1.0.0\n2.5D Cosmic Arcade Engine',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textDim, fontSize: 11, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profilePlayerCard() {
    final w = widget.wallet;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E1260), Color(0xFF14072E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withValues(alpha: 0.35),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                alignment: Alignment.bottomCenter,
                clipBehavior: Clip.none,
                children: [
                  Image.asset('assets/images/avatar/avatar_frame.png',
                      width: 68, height: 68),
                  Positioned(
                    bottom: -6,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 1.5),
                      decoration: BoxDecoration(
                        gradient: AppColors.goldGradient,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.navy, width: 1.5),
                      ),
                      child: Text('Lv ${w.level}',
                          style: const TextStyle(
                              color: AppColors.navy,
                              fontWeight: FontWeight.w900,
                              fontSize: 11)),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Cosmic Commander',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 18)),
                    const SizedBox(height: 4),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.teal.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border:
                            Border.all(color: AppColors.teal.withValues(alpha: 0.6)),
                      ),
                      child: const Text('STARLIGHT VIP',
                          style: TextStyle(
                              color: AppColors.teal,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                              letterSpacing: 1)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('LEVEL PROGRESSION',
                  style: TextStyle(
                      color: AppColors.textDim,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
              Text('${(w.levelProgress * 100).toInt()}%',
                  style: const TextStyle(
                      color: AppColors.teal,
                      fontSize: 12,
                      fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: w.levelProgress,
              minHeight: 10,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation(AppColors.teal),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
                '${w.xp % WalletService.xpPerLevel} / ${WalletService.xpPerLevel} XP to Level ${w.level + 1}',
                style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _profileSettingsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.deepPurple.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('GAME PREFERENCES',
              style: TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w800,
                  fontSize: 14)),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Audio & Haptic Feedback',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            subtitle: const Text(
                'Slot machine sound effects, reel vibration and win celebrations',
                style: TextStyle(color: AppColors.textDim, fontSize: 12)),
            activeThumbColor: AppColors.gold,
            value: sound.enabled,
            onChanged: (v) => sound.setEnabled(v),
          ),
        ],
      ),
    );
  }

  Widget _profileSandboxCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.deepPurple.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TESTING & RECHARGE',
              style: TextStyle(
                  color: AppColors.teal,
                  fontWeight: FontWeight.w800,
                  fontSize: 14)),
          const SizedBox(height: 6),
          const Text(
              'Instantly top up balances to test high-roller bets and unlocks.',
              style: TextStyle(color: AppColors.textDim, fontSize: 12)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: CosmicButton(
                  label: '+50K COINS',
                  height: 42,
                  onTap: () {
                    widget.wallet.addCoins(50000);
                    sound.win();
                    _notify('🪙 +50,000 Coins added!');
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CosmicButton(
                  label: '+20 GEMS',
                  height: 42,
                  gradient: const LinearGradient(
                      colors: [AppColors.teal, AppColors.purple]),
                  onTap: () {
                    widget.wallet.addGems(20);
                    sound.win();
                    _notify('💎 +20 Gems added!');
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // SHARED UI HELPERS & BOTTOM NAV
  // -------------------------------------------------------------
  Widget _tabHeader(String title, String subtitle, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.deepPurple.withValues(alpha: 0.85),
            AppColors.navy.withValues(alpha: 0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: AppColors.goldGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.navy, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 0.5)),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: AppColors.textDim, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.gold, size: 18),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
                letterSpacing: 1)),
      ],
    );
  }

  void _notify(String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.deepPurple,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.gold, width: 1),
        ),
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
        onTabSelected: (i) {
          setState(() => _navIndex = i);
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
