import 'dart:async';
import 'package:flutter/material.dart';
import '../models/slot_game.dart';
import '../services/engagement_service.dart';
import '../services/jackpot_service.dart';
import '../services/real_play_service.dart';
import '../services/sound_service.dart';
import '../services/wallet_service.dart';
import '../theme/app_theme.dart';
import '../widgets/cosmic_button.dart';
import '../widgets/cosmic_daily_view.dart';
import '../widgets/cosmic_mailbox_view.dart';
import '../widgets/cosmic_profile_view.dart';
import '../widgets/cosmic_store_view.dart';
import '../widgets/currency_bar.dart';
import '../widgets/game_tile.dart';
import '../widgets/slot_machine.dart';
import '../games/cosmic_fortune_config.dart';
import '../games/ways_configs.dart';
import '../games/hold_win_screen.dart';
import '../widgets/game_bottom_nav_bar.dart';
import '../widgets/game_toast.dart';

class LobbyScreen extends StatefulWidget {
  final WalletService wallet;
  final EngagementService engagement;
  final JackpotService jackpots;
  const LobbyScreen(
      {super.key,
      required this.wallet,
      required this.engagement,
      required this.jackpots});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  int _navIndex = 0;
  int _featured = 0;
  Timer? _rotator;
  Timer? _ticker; // refreshes the hourly countdown
  late final PageController _pageController;
  bool _userInteracting = false;

  EngagementService get eng => widget.engagement;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _featured);
    _startRotator();
    // Tick once a second so the hourly timer counts down live.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeRescue());
  }

  static int get _totalBannerSlides => kGames.length + 1;

  void _startRotator() {
    _rotator?.cancel();
    _rotator = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || _userInteracting || !_pageController.hasClients) return;
      final next = (_featured + 1) % _totalBannerSlides;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _rotator?.cancel();
    _ticker?.cancel();
    _pageController.dispose();
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
      GameToast.show(
        context,
        title: 'LOCKED GAME',
        message: 'Reach Level ${g.unlockLevel} to unlock ${g.name}',
        icon: Icons.lock_rounded,
        accentColor: AppColors.teal,
      );
      return;
    }
    final w = widget.wallet;
    // Career stat + daily-mission progress ("play N different games").
    w.recordGameOpened();
    eng.recordGameOpened(g.id);
    final Widget screen = switch (g.id) {
      'cosmic_fortune' => SlotMachine(
          title: g.name,
          config: cosmicFortuneConfig,
          wallet: w,
          engagement: eng,
          background: g.background),
      'galaxy_gold' => HoldWinScreen(
          title: g.name,
          wallet: w,
          engagement: eng,
          jackpots: widget.jackpots,
          background: g.background),
      'starburst_nova' => SlotMachine(
          title: g.name,
          config: starburstNovaConfig,
          wallet: w,
          engagement: eng,
          background: g.background,
          expandingWild: true),
      'lucky_nebula' => SlotMachine(
          title: g.name,
          config: luckyNebulaConfig,
          wallet: w,
          engagement: eng,
          background: g.background,
          cascades: true),
      'asteroid_blitz' => SlotMachine(
          title: g.name,
          config: asteroidBlitzConfig,
          wallet: w,
          engagement: eng,
          background: g.background,
          stickyWildSpins: 3),
      _ => SlotMachine(
          title: g.name,
          config: cosmicFortuneConfig,
          wallet: w,
          engagement: eng,
          background: g.background),
    };
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    // Playing may have leveled the player up → mint any level-reward gifts.
    eng.syncLevelRewards(widget.wallet);
  }

  void _openDaily() => setState(() => _navIndex = 3);

  void _claimHourly() {
    if (eng.claimHourly(widget.wallet)) {
      sound.win();
      GameToast.show(
        context,
        title: 'HOURLY BONUS',
        message: '+1,000 Coins claimed!',
        assetIcon: 'assets/images/currency/coin.png',
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
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                  child: CurrencyBar(wallet: widget.wallet, onGetCoins: _getCoins),
                ),
                Expanded(
                  child: IndexedStack(
                    index: _navIndex,
                    children: [
                      _lobbyView(),
                      CosmicStoreView(wallet: widget.wallet, engagement: eng),
                      CosmicMailboxView(
                        wallet: widget.wallet,
                        engagement: eng,
                        onGoToLobby: () => setState(() => _navIndex = 0),
                      ),
                      CosmicDailyView(
                        wallet: widget.wallet,
                        engagement: eng,
                      ),
                      CosmicProfileView(
                        wallet: widget.wallet,
                        engagement: eng,
                      ),
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
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 110),
      children: [
        Center(
          child: Image.asset('assets/images/branding/logo.png', height: 86),
        ),
        const SizedBox(height: 10),
        _featuredBanner(),
        const SizedBox(height: 16),
        _dailyButton(),
        const SizedBox(height: 18),
        _gameGrid(),
      ],
    );
  }

  Widget _featuredBanner() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 172,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification) {
                _userInteracting = true;
              } else if (notification is ScrollEndNotification) {
                _userInteracting = false;
                _startRotator();
              }
              return false;
            },
            child: PageView.builder(
              controller: _pageController,
              itemCount: _totalBannerSlides,
              physics: const BouncingScrollPhysics(),
              onPageChanged: (i) {
                setState(() => _featured = i);
              },
              itemBuilder: (context, i) {
                if (i < kGames.length) {
                  return _featuredCard(kGames[i]);
                }
                return _realPlayFeaturedCard();
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        // 2.5D Carousel Dot Selector
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_totalBannerSlides, (i) {
            final active = _featured == i;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                sound.tap();
                _pageController.animateToPage(
                  i,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  width: active ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: active ? AppColors.goldGradient : null,
                    color: active ? null : Colors.white.withValues(alpha: 0.28),
                    border: active
                        ? null
                        : Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 0.8,
                          ),
                    boxShadow: active
                        ? const [
                            BoxShadow(
                              color: Color(0x88FFB300),
                              offset: Offset(0, 1),
                              blurRadius: 5,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _realPlayFeaturedCard() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        sound.win();
        RealPlayService.openRealPlay();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF381503),
              Color(0xFF220A01),
              Color(0xFF130300),
            ],
          ),
          border: Border.all(
            color: const Color(0xFFFFB300),
            width: 1.6,
          ),
          boxShadow: [
            // 2.5D Solid Isometric Base Ledge
            const BoxShadow(
              color: Color(0xFF070000),
              offset: Offset(0, 5),
              blurRadius: 0,
            ),
            // Soft cast drop shadow
            const BoxShadow(
              color: Colors.black54,
              offset: Offset(0, 7),
              blurRadius: 8,
            ),
            // Ambient Neon Gold Glow
            BoxShadow(
              color: const Color(0xFFFF8F00).withValues(alpha: 0.35),
              offset: const Offset(0, 2),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18.5),
          child: Stack(
            children: [
              // Radial Stage Backlight behind art
              Positioned(
                left: -15,
                top: -15,
                bottom: -15,
                width: 190,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.65,
                      colors: [
                        const Color(0xFFFFB300).withValues(alpha: 0.40),
                        const Color(0xFFFF8F00).withValues(alpha: 0.10),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
              ),
              // Subtle Cosmic Top-Right Glimmer
              Positioned(
                right: -25,
                top: -25,
                width: 130,
                height: 130,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        AppColors.gold.withValues(alpha: 0.16),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Corner Gold Brackets
              Positioned(
                top: 6,
                left: 6,
                child: _GildedCorner(quarterTurns: 0, color: const Color(0xFFFFB300)),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: _GildedCorner(quarterTurns: 1, color: const Color(0xFFFFB300)),
              ),
              Positioned(
                bottom: 6,
                right: 6,
                child: _GildedCorner(quarterTurns: 2, color: const Color(0xFFFFB300)),
              ),
              Positioned(
                bottom: 6,
                left: 6,
                child: _GildedCorner(quarterTurns: 3, color: const Color(0xFFFFB300)),
              ),
              // Content Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // Real Cash Vault Illustration
                    Expanded(
                      flex: 11,
                      child: Center(
                        child: Image.asset(
                          'assets/images/engagement/reward_chest.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Information & Action
                    Expanded(
                      flex: 13,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFFF2A6D), Color(0xFFD30040)],
                                  ),
                                  borderRadius: BorderRadius.circular(5),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x66FF2A6D),
                                      offset: Offset(0, 1),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.workspace_premium_rounded,
                                        color: Colors.white, size: 9),
                                    SizedBox(width: 3),
                                    Text(
                                      'REAL CASH',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 8.5,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFFFB300), Color(0xFFFF6F00)],
                                  ),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: const Text(
                                  '100% MATCH',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 8.5,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Play on SpinnerLog',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              letterSpacing: 0.3,
                              shadows: [
                                Shadow(
                                  color: Colors.black,
                                  offset: Offset(0, 1.5),
                                  blurRadius: 3,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Win Real Jackpots · Instant Payouts',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(0xFFFFCC80),
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 10),
                          CosmicButton(
                            label: 'PLAY REAL NOW',
                            icon: Icons.open_in_new_rounded,
                            height: 38,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFB300), Color(0xFFFF6F00)],
                            ),
                            onTap: () {
                              sound.win();
                              RealPlayService.openRealPlay();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featuredCard(SlotGame g) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2C1352),
            Color(0xFF170933),
            Color(0xFF0C031A),
          ],
        ),
        border: Border.all(
          color: g.glow.withValues(alpha: 0.75),
          width: 1.6,
        ),
        boxShadow: [
          // 2.5D Solid Isometric Base Ledge
          const BoxShadow(
            color: Color(0xFF070014),
            offset: Offset(0, 5),
            blurRadius: 0,
          ),
          // Soft cast drop shadow
          const BoxShadow(
            color: Colors.black54,
            offset: Offset(0, 7),
            blurRadius: 8,
          ),
          // Ambient Neon Glow matching the game accent color
          BoxShadow(
            color: g.glow.withValues(alpha: 0.35),
            offset: const Offset(0, 2),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18.5),
        child: Stack(
          children: [
            // Radial Aura Behind Featured Art
            Positioned(
              left: -15,
              top: -15,
              bottom: -15,
              width: 190,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.65,
                    colors: [
                      g.glow.withValues(alpha: 0.40),
                      g.glow.withValues(alpha: 0.10),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
            // Subtle Cosmic Top-Right Glimmer
            Positioned(
              right: -25,
              top: -25,
              width: 130,
              height: 130,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      AppColors.gold.withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Subtle decorative corner gold brackets
            Positioned(
              top: 6,
              left: 6,
              child: _GildedCorner(quarterTurns: 0, color: g.glow),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: _GildedCorner(quarterTurns: 1, color: g.glow),
            ),
            Positioned(
              bottom: 6,
              right: 6,
              child: _GildedCorner(quarterTurns: 2, color: g.glow),
            ),
            Positioned(
              bottom: 6,
              left: 6,
              child: _GildedCorner(quarterTurns: 3, color: g.glow),
            ),
            // Content Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Featured Game Illustration
                  Expanded(
                    flex: 11,
                    child: Center(
                      child: Image.asset(
                        g.asset,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Featured Information & Action
                  Expanded(
                    flex: 13,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF00E5FF), Color(0xFF0077B6)],
                                ),
                                borderRadius: BorderRadius.circular(5),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x6600E5FF),
                                    offset: Offset(0, 1),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.auto_awesome,
                                      color: Colors.white, size: 9),
                                  SizedBox(width: 3),
                                  Text(
                                    'SPOTLIGHT',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 9,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (g.badge != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2.5),
                                decoration: BoxDecoration(
                                  gradient: g.badge == 'HOT'
                                      ? const LinearGradient(colors: [
                                          Color(0xFFFF2A6D),
                                          Color(0xFFD30040)
                                        ])
                                      : const LinearGradient(colors: [
                                          Color(0xFF00F5D4),
                                          Color(0xFF00B4D8)
                                        ]),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  g.badge!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 8.5,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          g.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            letterSpacing: 0.3,
                            shadows: [
                              Shadow(
                                color: Colors.black,
                                offset: Offset(0, 1.5),
                                blurRadius: 3,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          g.tagline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFD3C5EE),
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 10),
                        CosmicButton(
                          label: 'PLAY NOW',
                          icon: Icons.play_arrow_rounded,
                          height: 38,
                          onTap: () => _openGame(g),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dailyButton() {
    return ListenableBuilder(
      listenable: eng,
      builder: (context, _) => Row(
        children: [
          Expanded(
            child: _DailyWheelConsole(
              canClaim: eng.canSpinWheel || eng.canClaimDaily,
              onTap: _openDaily,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _HourlyVaultConsole(
              canClaim: eng.canClaimHourly,
              remaining: eng.hourlyRemaining,
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
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: kGames.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 14,
          childAspectRatio: 0.80,
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
  // TAB 1: STORE -> Provided by CosmicStoreView in widgets/cosmic_store_view.dart
  // -------------------------------------------------------------

  // -------------------------------------------------------------
  // TAB 2: MAILBOX -> Provided by CosmicMailboxView in widgets/cosmic_mailbox_view.dart
  // -------------------------------------------------------------

  // -------------------------------------------------------------
  // TAB 3: DAILY -> Provided by CosmicDailyView in widgets/cosmic_daily_view.dart
  // -------------------------------------------------------------

  // -------------------------------------------------------------
  // TAB 4: PROFILE -> Provided by CosmicProfileView in widgets/cosmic_profile_view.dart
  // -------------------------------------------------------------





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
            const SizedBox(height: 10),
            CosmicButton(
              label: 'DEPOSIT & PLAY REAL CASH',
              icon: Icons.open_in_new_rounded,
              width: double.infinity,
              gradient: const LinearGradient(
                colors: [Color(0xFFFFB300), Color(0xFFFF6F00)],
              ),
              onTap: () {
                RealPlayService.openRealPlay();
                onCollect();
              },
            ),
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
        width: 13,
        height: 13,
        decoration: BoxDecoration(
          color: AppColors.magenta,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.8),
          boxShadow: [
            BoxShadow(
              color: AppColors.magenta.withValues(alpha: 0.8),
              blurRadius: 6,
            ),
          ],
        ),
      );
}

/// 2.5D Daily Lucky Wheel Console matching the console bottom dock aesthetic.
class _DailyWheelConsole extends StatefulWidget {
  final bool canClaim;
  final VoidCallback onTap;

  const _DailyWheelConsole({
    required this.canClaim,
    required this.onTap,
  });

  @override
  State<_DailyWheelConsole> createState() => _DailyWheelConsoleState();
}

class _DailyWheelConsoleState extends State<_DailyWheelConsole> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final canClaim = widget.canClaim;
    final double translateY = _down ? 2.5 : 0.0;
    final double extrusionHeight = _down ? 1.5 : 4.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        sound.tap();
        setState(() => _down = true);
      },
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, translateY, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: canClaim
                ? const [
                    Color(0xFF38104D),
                    Color(0xFF200732),
                    Color(0xFF0F021B),
                  ]
                : const [
                    Color(0xFF220F31),
                    Color(0xFF14061F),
                    Color(0xFF0B0311),
                  ],
          ),
          border: Border.all(
            color: canClaim
                ? AppColors.magenta.withValues(alpha: _down ? 0.95 : 0.75)
                : const Color(0xFF6A4480).withValues(alpha: 0.4),
            width: 1.3,
          ),
          boxShadow: [
            // 2.5D Solid Isometric Base Ledge
            BoxShadow(
              color: const Color(0xFF070014),
              offset: Offset(0, extrusionHeight),
              blurRadius: 0,
            ),
            // Soft cast shadow
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              offset: Offset(0, extrusionHeight + 2),
              blurRadius: 4,
            ),
            // Ambient Neon Glow
            if (canClaim && !_down)
              BoxShadow(
                color: AppColors.magenta.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: Offset(0, extrusionHeight),
              ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              // Wheel Medallion Stage
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [
                          Color(0xFF3D165E),
                          Color(0xFF18052A),
                        ],
                      ),
                      border: Border.all(
                        color: canClaim
                            ? AppColors.gold
                            : const Color(0xFF8860B0).withValues(alpha: 0.5),
                        width: 1.3,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0xFF0A0018),
                          offset: Offset(0, 1.5),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(2.5),
                    child: Image.asset(
                      'assets/images/engagement/daily_wheel.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  if (canClaim)
                    const Positioned(
                      top: -2,
                      right: -2,
                      child: _ReadyDot(),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              // Content Column
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LUCKY WHEEL',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: canClaim ? AppColors.gold : Colors.white70,
                        fontWeight: FontWeight.w900,
                        fontSize: 11.5,
                        letterSpacing: 0.3,
                        shadows: const [
                          Shadow(
                            color: Colors.black,
                            offset: Offset(0, 1),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      canClaim ? 'Daily Free Spin' : 'Collected Today',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: canClaim ? const Color(0xFFE5CEFC) : Colors.white38,
                        fontWeight: FontWeight.w600,
                        fontSize: 9.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Action Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: canClaim ? AppColors.goldGradient : null,
                        color: canClaim ? null : const Color(0xFF190924),
                        borderRadius: BorderRadius.circular(4),
                        border: canClaim
                            ? null
                            : Border.all(color: Colors.white12, width: 0.8),
                        boxShadow: canClaim
                            ? const [
                                BoxShadow(
                                  color: Color(0xFF261200),
                                  offset: Offset(0, 1),
                                  blurRadius: 0,
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        canClaim ? 'SPIN NOW ▶' : 'DONE',
                        style: TextStyle(
                          color: canClaim ? AppColors.navy : Colors.white38,
                          fontWeight: FontWeight.w900,
                          fontSize: 8.5,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 2.5D Hourly Vault Console matching the console bottom dock aesthetic.
class _HourlyVaultConsole extends StatefulWidget {
  final bool canClaim;
  final Duration remaining;
  final VoidCallback? onTap;

  const _HourlyVaultConsole({
    required this.canClaim,
    required this.remaining,
    required this.onTap,
  });

  @override
  State<_HourlyVaultConsole> createState() => _HourlyVaultConsoleState();
}

class _HourlyVaultConsoleState extends State<_HourlyVaultConsole> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final canClaim = widget.canClaim;
    final enabled = widget.onTap != null;
    final double translateY = _down ? 2.5 : 0.0;
    final double extrusionHeight = _down ? 1.5 : 4.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled
          ? (_) {
              sound.tap();
              setState(() => _down = true);
            }
          : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _down = false);
              widget.onTap!();
            }
          : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, translateY, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: canClaim
                ? const [
                    Color(0xFF0C3834),
                    Color(0xFF072422),
                    Color(0xFF031211),
                  ]
                : const [
                    Color(0xFF09211E),
                    Color(0xFF051513),
                    Color(0xFF020B0A),
                  ],
          ),
          border: Border.all(
            color: canClaim
                ? AppColors.teal.withValues(alpha: _down ? 0.95 : 0.75)
                : const Color(0xFF265A54).withValues(alpha: 0.4),
            width: 1.3,
          ),
          boxShadow: [
            // 2.5D Solid Isometric Base Ledge
            BoxShadow(
              color: const Color(0xFF070014),
              offset: Offset(0, extrusionHeight),
              blurRadius: 0,
            ),
            // Soft cast shadow
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              offset: Offset(0, extrusionHeight + 2),
              blurRadius: 4,
            ),
            // Ambient Neon Glow
            if (canClaim && !_down)
              BoxShadow(
                color: AppColors.teal.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: Offset(0, extrusionHeight),
              ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              // Chest Medallion Stage
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [
                          Color(0xFF0C4D46),
                          Color(0xFF041E1C),
                        ],
                      ),
                      border: Border.all(
                        color: canClaim
                            ? const Color(0xFF4DFBD0)
                            : const Color(0xFF266E64).withValues(alpha: 0.5),
                        width: 1.3,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0xFF02100E),
                          offset: Offset(0, 1.5),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(3.5),
                    child: Image.asset(
                      'assets/images/engagement/reward_chest.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  if (canClaim)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: AppColors.teal,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.8),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.teal.withValues(alpha: 0.8),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              // Content Column
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HOURLY VAULT',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: canClaim ? const Color(0xFF64FFDA) : Colors.white70,
                        fontWeight: FontWeight.w900,
                        fontSize: 11.0,
                        letterSpacing: 0.1,
                        shadows: const [
                          Shadow(
                            color: Colors.black,
                            offset: Offset(0, 1),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      canClaim ? '+1,000 Coins' : 'Next Free Drop',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: canClaim ? const Color(0xFFB2DFDB) : Colors.white38,
                        fontWeight: FontWeight.w600,
                        fontSize: 9.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Action Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: canClaim
                            ? const LinearGradient(
                                colors: [Color(0xFF00E5FF), Color(0xFF00B4D8)],
                              )
                            : null,
                        color: canClaim ? null : const Color(0xFF061816),
                        borderRadius: BorderRadius.circular(4),
                        border: canClaim
                            ? null
                            : Border.all(color: Colors.white12, width: 0.8),
                        boxShadow: canClaim
                            ? const [
                                BoxShadow(
                                  color: Color(0xFF002229),
                                  offset: Offset(0, 1),
                                  blurRadius: 0,
                                ),
                              ]
                            : null,
                      ),
                      child: canClaim
                          ? const Text(
                              'CLAIM ▶',
                              style: TextStyle(
                                color: AppColors.navy,
                                fontWeight: FontWeight.w900,
                                fontSize: 8.5,
                                letterSpacing: 0.3,
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.timer_outlined,
                                  size: 9,
                                  color: AppColors.gold,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  _LobbyScreenState._fmtDuration(widget.remaining),
                                  style: const TextStyle(
                                    color: AppColors.gold,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 8.5,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Subtle ornamental 2.5D gold corner bracket for the featured carousel cards.
class _GildedCorner extends StatelessWidget {
  final int quarterTurns;
  final Color color;

  const _GildedCorner({
    required this.quarterTurns,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return RotatedBox(
      quarterTurns: quarterTurns,
      child: CustomPaint(
        size: const Size(12, 12),
        painter: _CornerBracketPainter(color: color),
      ),
    );
  }
}

class _CornerBracketPainter extends CustomPainter {
  final Color color;

  _CornerBracketPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.75)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CornerBracketPainter oldDelegate) =>
      oldDelegate.color != color;
}
