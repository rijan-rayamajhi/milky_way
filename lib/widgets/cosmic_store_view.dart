import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/real_play_service.dart';
import '../services/sound_service.dart';
import '../services/wallet_service.dart';
import '../services/engagement_service.dart';
import '../theme/app_theme.dart';
import 'cosmic_button.dart';
import 'currency_bar.dart';
import 'game_toast.dart';

enum StoreCategory { all, coins, gems, specials }

/// Represents an item in the Cosmic Treasury store.
class StorePack {
  final String id;
  final String title;
  final String subtitle;
  final String asset;
  final int coins;
  final int gems;
  final int xp;
  final int costCoins; // price paid in coins (gem packs)
  final int costGems; // price paid in gems (coin packs)
  final String badge;
  final Color badgeColor;
  final String? valueMultiplier;
  final String cta;
  final StoreCategory category;
  final Gradient? buttonGradient;
  final bool isHighRoller;

  const StorePack({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.asset,
    this.coins = 0,
    this.gems = 0,
    this.xp = 0,
    this.costCoins = 0,
    this.costGems = 0,
    required this.badge,
    required this.badgeColor,
    this.valueMultiplier,
    required this.cta,
    required this.category,
    this.buttonGradient,
    this.isHighRoller = false,
  });

  bool get paidInGems => costGems > 0;
}

/// Production-ready AAA Game Store for the Cosmic Treasury.
class CosmicStoreView extends StatefulWidget {
  final WalletService wallet;
  final EngagementService engagement;

  const CosmicStoreView({
    super.key,
    required this.wallet,
    required this.engagement,
  });

  @override
  State<CosmicStoreView> createState() => _CosmicStoreViewState();
}

class _CosmicStoreViewState extends State<CosmicStoreView>
    with SingleTickerProviderStateMixin {
  StoreCategory _selectedCategory = StoreCategory.all;
  late final AnimationController _pulseController;
  Timer? _countdownTimer;

  // Daily faucet state is owned by EngagementService (persisted), not local.
  bool get _freePackClaimed => !widget.engagement.canClaimStorePack;
  bool get _flashClaimed => !widget.engagement.canClaimFlashDeal;
  Duration get _flashDealRemaining => widget.engagement.flashResetRemaining;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    // Live refresh so the midnight reset countdown ticks.
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _formatTimer(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  // Packs catalog. Coin vaults are bought with GEMS; gem caches are forged
  // from COINS — so both currencies are real sinks, not a free faucet.
  List<StorePack> get _packs => [
        // Coin Vaults (cost gems @ ~2k coins/gem value, scaling bonus)
        const StorePack(
          id: 'pouch_25k',
          title: 'Nebula Pouch',
          subtitle: 'Starter coin bundle',
          asset: 'assets/images/currency/coin.png',
          coins: 25000,
          xp: 50,
          costGems: 12,
          badge: 'POPULAR',
          badgeColor: AppColors.teal,
          valueMultiplier: '+4% BONUS',
          cta: 'BUY',
          category: StoreCategory.coins,
        ),
        const StorePack(
          id: 'stash_100k',
          title: 'Supernova Stash',
          subtitle: 'Cosmic value pack',
          asset: 'assets/images/currency/coin.png',
          coins: 100000,
          xp: 150,
          costGems: 45,
          badge: 'HOT DEAL',
          badgeColor: AppColors.magenta,
          valueMultiplier: '+11% VALUE',
          cta: 'BUY',
          category: StoreCategory.coins,
        ),
        const StorePack(
          id: 'treasury_500k',
          title: 'Galactic Vault',
          subtitle: 'High roller fortune',
          asset: 'assets/images/currency/coin.png',
          coins: 500000,
          xp: 500,
          costGems: 200,
          badge: 'BEST VALUE',
          badgeColor: AppColors.gold,
          valueMultiplier: '+25% VALUE',
          cta: 'BUY',
          category: StoreCategory.coins,
          isHighRoller: true,
        ),
        const StorePack(
          id: 'omni_1m',
          title: 'Omni Treasury',
          subtitle: 'Supreme jackpot cache',
          asset: 'assets/images/engagement/reward_chest.png',
          coins: 1000000,
          xp: 1000,
          costGems: 380,
          badge: 'JACKPOT',
          badgeColor: Color(0xFFFF5252),
          valueMultiplier: '+32% VALUE',
          cta: 'BUY',
          category: StoreCategory.coins,
          isHighRoller: true,
        ),

        // Gem Caches (forged from coins)
        const StorePack(
          id: 'shards_50',
          title: 'Starlight Shards',
          subtitle: 'Forge gems from coins',
          asset: 'assets/images/currency/gem.png',
          gems: 50,
          xp: 80,
          costCoins: 150000,
          badge: 'GEMS',
          badgeColor: AppColors.teal,
          cta: 'FORGE',
          category: StoreCategory.gems,
          buttonGradient: LinearGradient(
            colors: [Color(0xFF26E0D8), Color(0xFF00897B)],
          ),
        ),
        const StorePack(
          id: 'cache_250',
          title: 'Crown Diamond',
          subtitle: 'Mega jewel stash',
          asset: 'assets/images/currency/gem.png',
          gems: 250,
          xp: 350,
          costCoins: 650000,
          badge: 'MEGA PACK',
          badgeColor: AppColors.gold,
          valueMultiplier: '+8% VALUE',
          cta: 'FORGE',
          category: StoreCategory.gems,
          buttonGradient: LinearGradient(
            colors: [Color(0xFFE040FB), Color(0xFF7B1FA2)],
          ),
        ),
        const StorePack(
          id: 'celestial_1000',
          title: 'Celestial Hoard',
          subtitle: 'Ultimate starlight hoard',
          asset: 'assets/images/currency/gem.png',
          gems: 1000,
          xp: 1200,
          costCoins: 2400000,
          badge: 'LEGENDARY',
          badgeColor: Color(0xFF00E5FF),
          valueMultiplier: '+20% VALUE',
          cta: 'FORGE',
          category: StoreCategory.gems,
          buttonGradient: LinearGradient(
            colors: [Color(0xFF00E5FF), Color(0xFF0091EA)],
          ),
          isHighRoller: true,
        ),
      ];

  bool _canAfford(StorePack pack) => pack.paidInGems
      ? widget.wallet.gems >= pack.costGems
      : widget.wallet.coins >= pack.costCoins;

  void _buyPack(StorePack pack) {
    final paid = pack.paidInGems
        ? widget.wallet.spendGems(pack.costGems)
        : widget.wallet.spendCoins(pack.costCoins);
    if (!paid) {
      sound.tap();
      GameToast.show(
        context,
        title: pack.paidInGems ? 'NOT ENOUGH GEMS' : 'NOT ENOUGH COINS',
        message: pack.paidInGems
            ? 'You need ${pack.costGems} gems for ${pack.title}.'
            : 'You need ${CurrencyBar.format(pack.costCoins)} coins for ${pack.title}.',
        icon: Icons.lock_rounded,
        accentColor: pack.paidInGems ? AppColors.teal : AppColors.gold,
      );
      return;
    }

    if (pack.coins > 0) widget.wallet.addCoins(pack.coins);
    if (pack.gems > 0) widget.wallet.addGems(pack.gems);
    if (pack.xp > 0) widget.wallet.addXp(pack.xp);

    if (pack.isHighRoller) {
      sound.bigWin();
    } else {
      sound.win();
    }

    _showRewardModal(
      title: pack.paidInGems ? 'VAULT UNLOCKED!' : 'GEMS FORGED!',
      packName: pack.title,
      coins: pack.coins,
      gems: pack.gems,
      xp: pack.xp,
      iconAsset: pack.asset,
    );
  }

  void _claimDailyKit() {
    if (!widget.engagement.claimStorePack(widget.wallet)) {
      sound.tap();
      return;
    }
    sound.win();
    _showRewardModal(
      title: 'EXPLORER KIT OPENED!',
      packName: 'Daily Cosmic Explorer Kit',
      coins: EngagementService.storePackCoins,
      gems: EngagementService.storePackGems,
      xp: 0,
      iconAsset: 'assets/images/engagement/reward_chest.png',
    );
  }

  void _claimFlashDeal() {
    if (!widget.engagement.canClaimFlashDeal) {
      sound.tap();
      return;
    }
    if (!widget.engagement.claimFlashDeal(widget.wallet)) {
      sound.tap();
      GameToast.show(
        context,
        title: 'NOT ENOUGH GEMS',
        message:
            'The flash deal costs ${EngagementService.flashDealGemCost} gems.',
        icon: Icons.lock_rounded,
        accentColor: AppColors.teal,
      );
      return;
    }
    sound.bigWin();
    _showRewardModal(
      title: 'FLASH DEAL CLAIMED!',
      packName: 'Supernova Flash Bundle',
      coins: EngagementService.flashDealCoins,
      gems: EngagementService.flashDealGems,
      xp: 0,
      iconAsset: 'assets/images/engagement/reward_chest.png',
    );
  }

  void _exchangeGems(int gems) {
    final coins = widget.wallet.exchangeGemsForCoins(gems);
    if (coins == 0) {
      sound.tap();
      GameToast.show(
        context,
        title: 'NOT ENOUGH GEMS',
        message: 'You need $gems gems to exchange.',
        icon: Icons.lock_rounded,
        accentColor: AppColors.teal,
      );
      return;
    }
    sound.win();
    GameToast.show(
      context,
      title: 'EXCHANGED',
      message: '$gems gems → ${CurrencyBar.format(coins)} coins!',
      assetIcon: 'assets/images/currency/coin.png',
    );
  }

  void _showRewardModal({
    required String title,
    required String packName,
    required int coins,
    required int gems,
    required int xp,
    required String iconAsset,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.8),
      transitionDuration: const Duration(milliseconds: 320),
      transitionBuilder: (context, anim, secAnim, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return ScaleTransition(scale: curved, child: child);
      },
      pageBuilder: (context, anim1, anim2) {
        return _VaultRewardDialog(
          title: title,
          packName: packName,
          coins: coins,
          gems: gems,
          xp: xp,
          iconAsset: iconAsset,
          onCollect: () => Navigator.of(context).pop(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.wallet, widget.engagement]),
      builder: (context, _) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final filteredPacks = _packs.where((p) {
      if (_selectedCategory == StoreCategory.all) return true;
      if (_selectedCategory == StoreCategory.coins) {
        return p.category == StoreCategory.coins;
      }
      if (_selectedCategory == StoreCategory.gems) {
        return p.category == StoreCategory.gems;
      }
      if (_selectedCategory == StoreCategory.specials) {
        return p.isHighRoller || p.valueMultiplier != null;
      }
      return true;
    }).toList();

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 115),
      children: [
        // 1. Ornate Game Header Banner
        _buildStoreHeader(),

        const SizedBox(height: 12),

        // 1b. Real Money VIP Redirection Banner
        _buildRealPlayStoreBanner(),

        const SizedBox(height: 12),

        // 2. Interactive Arcade Filter Bar
        _buildCategoryFilters(),

        const SizedBox(height: 14),

        // 3. Limited-Time Flash Deal (Hero Banner)
        if (_selectedCategory == StoreCategory.all ||
            _selectedCategory == StoreCategory.specials) ...[
          _buildFlashDealCard(),
          const SizedBox(height: 16),
        ],

        // 4. Daily Free Explorer Kit
        if (_selectedCategory == StoreCategory.all ||
            _selectedCategory == StoreCategory.specials) ...[
          _buildDailyFreeChestCard(),
          const SizedBox(height: 14),
        ],

        // 4b. Gem → Coin Exchange
        if (_selectedCategory == StoreCategory.all ||
            _selectedCategory == StoreCategory.coins) ...[
          _buildExchangeCard(),
          const SizedBox(height: 20),
        ],

        // 5. Section Title
        _buildSectionHeader(
          _selectedCategory == StoreCategory.gems
              ? 'STARLIGHT GEM CACHE'
              : _selectedCategory == StoreCategory.coins
                  ? 'COSMIC COIN VAULTS'
                  : 'FEATURED VAULT PACKS',
          _selectedCategory == StoreCategory.gems
              ? Icons.diamond_rounded
              : Icons.monetization_on_rounded,
        ),

        const SizedBox(height: 12),

        // 6. High-Impact 2-Column Game Pack Cards
        _buildPacksGrid(filteredPacks),

        const SizedBox(height: 14),

        // 7. Cosmic VIP Perks Hub
        _buildVipClubStrip(),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER
  // ---------------------------------------------------------------------------
  Widget _buildStoreHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF28114D),
            Color(0xFF130628),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.55),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF070014),
            offset: const Offset(0, 4),
            blurRadius: 0,
          ),
          BoxShadow(
            color: AppColors.purple.withValues(alpha: 0.35),
            offset: const Offset(0, 2),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          // Left ornate vault crest
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppColors.goldGradient,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFFF3B0), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.5),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: Color(0xFF190632),
              size: 26,
            ),
          ),
          const SizedBox(width: 12),

          // Center Title + Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text(
                      'COSMIC TREASURY',
                      style: TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w900,
                        fontSize: 16.5,
                        letterSpacing: 0.8,
                        shadows: [
                          Shadow(
                            color: Colors.black87,
                            offset: Offset(0, 1.5),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.auto_awesome, color: AppColors.gold, size: 14),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'Galactic Coin Vaults & Celestial Gems',
                  style: TextStyle(
                    color: AppColors.textDim,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // VIP Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF381468), Color(0xFF1E083B)],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.teal, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.teal.withValues(alpha: 0.3),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.stars_rounded, color: AppColors.teal, size: 12),
                    const SizedBox(width: 3),
                    Text(
                      'VIP ${widget.wallet.level}',
                      style: const TextStyle(
                        color: AppColors.teal,
                        fontWeight: FontWeight.w900,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
                const Text(
                  '+10% BONUS',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 7.5,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // REAL MONEY VIP PLAY BANNER
  // ---------------------------------------------------------------------------
  Widget _buildRealPlayStoreBanner() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        sound.win();
        RealPlayService.openRealPlay();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF381504),
              Color(0xFF220901),
              Color(0xFF140300),
            ],
          ),
          border: Border.all(
            color: const Color(0xFFFFB300),
            width: 1.5,
          ),
          boxShadow: [
            const BoxShadow(
              color: Color(0xFF0A0200),
              offset: Offset(0, 4),
              blurRadius: 0,
            ),
            BoxShadow(
              color: const Color(0xFFFF9100).withValues(alpha: 0.35),
              offset: const Offset(0, 2),
              blurRadius: 14,
            ),
          ],
        ),
        child: Row(
          children: [
            // Gold Casino Chips / Diamond Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD54F), Color(0xFFFF8F00)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFB300).withValues(alpha: 0.6),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: const Icon(
                Icons.monetization_on_rounded,
                color: Color(0xFF2E1200),
                size: 26,
              ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF5252), Color(0xFFFF1744)],
                          ),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text(
                          'REAL CASH PLAY',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 8.5,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Flexible(
                        child: Text(
                          '100% MATCH',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xFFFFD54F),
                            fontWeight: FontWeight.w900,
                            fontSize: 9.5,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Play for Real Money on SpinnerLog',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13.5,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const Text(
                    'Instant Withdrawals · Real Jackpots',
                    style: TextStyle(
                      color: Color(0xFFFFCC80),
                      fontWeight: FontWeight.w600,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // CTA Button
            CosmicButton(
              label: 'PLAY REAL',
              icon: Icons.open_in_new_rounded,
              height: 36,
              width: 104,
              fontSize: 10.5,
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
    );
  }

  // ---------------------------------------------------------------------------
  // FILTER TABS
  // ---------------------------------------------------------------------------
  Widget _buildCategoryFilters() {
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0524),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          _filterPill('ALL', StoreCategory.all, Icons.dashboard_rounded),
          _filterPill('COINS', StoreCategory.coins, Icons.monetization_on_rounded),
          _filterPill('GEMS', StoreCategory.gems, Icons.diamond_rounded),
          _filterPill('SPECIALS', StoreCategory.specials, Icons.local_fire_department_rounded),
        ],
      ),
    );
  }

  Widget _filterPill(String label, StoreCategory category, IconData icon) {
    final active = _selectedCategory == category;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          sound.tap();
          setState(() => _selectedCategory = category);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: active ? AppColors.goldGradient : null,
            borderRadius: BorderRadius.circular(9),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.4),
                      blurRadius: 6,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 13,
                color: active ? const Color(0xFF16052B) : AppColors.textDim,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: active ? const Color(0xFF16052B) : AppColors.textDim,
                  fontWeight: FontWeight.w900,
                  fontSize: 10.5,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FLASH DEAL HERO CARD
  // ---------------------------------------------------------------------------
  Widget _buildFlashDealCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold, width: 1.8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF090017),
            offset: const Offset(0, 5),
            blurRadius: 0,
          ),
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.35),
            blurRadius: 14,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            // Background cosmic gradient
            Container(
              height: 156,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF4A1054),
                    Color(0xFF240738),
                    Color(0xFF140224),
                  ],
                ),
              ),
            ),

            // Rotating Sunburst rays overlay
            Positioned(
              right: -30,
              top: -30,
              width: 220,
              height: 220,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, _) {
                  return Transform.rotate(
                    angle: _pulseController.value * math.pi * 0.1,
                    child: CustomPaint(
                      painter: _SunburstRaysPainter(
                        color: AppColors.gold.withValues(alpha: 0.08),
                        spokeCount: 16,
                      ),
                    ),
                  );
                },
              ),
            ),

            // Top Header Ribbon: Countdown Timer + Flash Tag
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFFF1744),
                      Color(0xFFD50000),
                      Color(0xFF880E4F),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.bolt_rounded,
                      color: Color(0xFFFFF176),
                      size: 15,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'LIMITED FLASH DEAL',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 10.5,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.timer_rounded,
                            color: Color(0xFFFFF176),
                            size: 11,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            _formatTimer(_flashDealRemaining),
                            style: const TextStyle(
                              color: Color(0xFFFFF176),
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Main Content Area
            Positioned(
              top: 32,
              left: 12,
              right: 12,
              bottom: 10,
              child: Row(
                children: [
                  // Visual 3D Hero Art with pulsing glow
                  SizedBox(
                    width: 86,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.gold.withValues(alpha: 0.18),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.gold.withValues(alpha: 0.4),
                                blurRadius: 18,
                              ),
                            ],
                          ),
                        ),
                        Image.asset(
                          'assets/images/engagement/reward_chest.png',
                          width: 80,
                        ),
                        // 80% OFF sash tag
                        Positioned(
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: AppColors.goldGradient,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: const Color(0xFF261002), width: 1),
                            ),
                            child: const Text(
                              '5X VALUE',
                              style: TextStyle(
                                color: Color(0xFF261002),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Pack Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'SUPERNOVA BUNDLE',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Image.asset('assets/images/currency/coin.png',
                                width: 17, height: 17),
                            const SizedBox(width: 4),
                            Text(
                              '+${CurrencyBar.format(EngagementService.flashDealCoins)}',
                              style: const TextStyle(
                                color: AppColors.gold,
                                fontWeight: FontWeight.w900,
                                fontSize: 13.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Image.asset('assets/images/currency/gem.png',
                                width: 15, height: 15),
                            const SizedBox(width: 3),
                            Text(
                              '+${EngagementService.flashDealGems}',
                              style: const TextStyle(
                                color: AppColors.teal,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _flashClaimed
                                ? '✓ Claimed today'
                                : 'Costs ${EngagementService.flashDealGemCost} 💎 • once daily',
                            style: const TextStyle(
                              color: Color(0xFFFFE082),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 6),

                  // 2.5D Claim Button
                  CosmicButton(
                    label: _flashClaimed ? 'DONE' : 'GET NOW',
                    height: 42,
                    width: 84,
                    fontSize: 12,
                    gradient: _flashClaimed
                        ? const LinearGradient(
                            colors: [Color(0xFF424242), Color(0xFF212121)])
                        : null,
                    onTap: _flashClaimed ? null : _claimFlashDeal,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DAILY FREE EXPLORER KIT
  // ---------------------------------------------------------------------------
  Widget _buildDailyFreeChestCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2D145A),
            Color(0xFF15072F),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _freePackClaimed
              ? AppColors.textDim.withValues(alpha: 0.4)
              : AppColors.teal,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF090117),
            offset: const Offset(0, 4),
            blurRadius: 0,
          ),
          if (!_freePackClaimed)
            BoxShadow(
              color: AppColors.teal.withValues(alpha: 0.35),
              blurRadius: 12,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Row(
        children: [
          // Glowing reward chest
          Stack(
            alignment: Alignment.center,
            children: [
              if (!_freePackClaimed)
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) => Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.teal.withValues(
                        alpha: 0.15 + _pulseController.value * 0.15,
                      ),
                    ),
                  ),
                ),
              Image.asset(
                'assets/images/engagement/reward_chest.png',
                width: 52,
                height: 52,
              ),
            ],
          ),

          const SizedBox(width: 12),

          // Title & Rewards
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: _freePackClaimed
                            ? Colors.grey.shade700
                            : const Color(0xFF00E676),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _freePackClaimed ? 'CLAIMED TODAY' : 'FREE DAILY PACK',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (!_freePackClaimed)
                      const Icon(Icons.stars, color: AppColors.gold, size: 13),
                  ],
                ),
                const SizedBox(height: 3),
                const Text(
                  'Cosmic Explorer Kit',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Image.asset('assets/images/currency/coin.png',
                        width: 14, height: 14),
                    const SizedBox(width: 3),
                    const Text(
                      '+10,000',
                      style: TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Image.asset('assets/images/currency/gem.png',
                        width: 13, height: 13),
                    const SizedBox(width: 3),
                    const Text(
                      '+5 Gems',
                      style: TextStyle(
                        color: AppColors.teal,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Button
          CosmicButton(
            label: _freePackClaimed ? 'DONE' : 'FREE',
            height: 38,
            width: 78,
            fontSize: 12,
            gradient: _freePackClaimed
                ? const LinearGradient(
                    colors: [Color(0xFF424242), Color(0xFF212121)],
                  )
                : const LinearGradient(
                    colors: [Color(0xFF69F0AE), Color(0xFF00C853)],
                  ),
            onTap: _freePackClaimed ? null : _claimDailyKit,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // GEM → COIN EXCHANGE
  // ---------------------------------------------------------------------------
  Widget _buildExchangeCard() {
    final gems = widget.wallet.gems;
    Widget option(int g) {
      final enabled = gems >= g;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: CosmicButton(
            label: '$g 💎',
            height: 40,
            fontSize: 11.5,
            gradient: enabled
                ? const LinearGradient(colors: [Color(0xFF26E0D8), Color(0xFF009688)])
                : const LinearGradient(colors: [Color(0xFF37474F), Color(0xFF263238)]),
            onTap: enabled ? () => _exchangeGems(g) : null,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF123A3E), Color(0xFF0C1E2A)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.5), width: 1.2),
        boxShadow: const [
          BoxShadow(color: Color(0xFF060012), offset: Offset(0, 4), blurRadius: 0),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.swap_horiz_rounded, color: AppColors.teal, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'GEM EXCHANGE',
                  style: TextStyle(
                    color: AppColors.teal,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              Text(
                '1 💎 = ${CurrencyBar.format(WalletService.gemToCoinRate)}',
                style: const TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Convert spare gems into coins instantly. You hold $gems 💎.',
            style: const TextStyle(color: AppColors.textDim, fontSize: 11.5),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              option(10),
              option(50),
              if (gems > 0)
                option(gems)
              else
                option(100),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION HEADER
  // ---------------------------------------------------------------------------
  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: AppColors.gold, size: 16),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 13.5,
            letterSpacing: 0.8,
            shadows: [
              Shadow(
                color: Colors.black87,
                offset: Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          ),
        ),
        const Spacer(),
        Text(
          '${_packs.length} PACKS',
          style: const TextStyle(
            color: AppColors.textDim,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 2-COLUMN PACKS GRID
  // ---------------------------------------------------------------------------
  Widget _buildPacksGrid(List<StorePack> packs) {
    if (packs.isEmpty) {
      return const SizedBox.shrink();
    }

    final rows = <Widget>[];
    for (int i = 0; i < packs.length; i += 2) {
      final pack1 = packs[i];
      final pack2 = i + 1 < packs.length ? packs[i + 1] : null;

      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StoreGridPackCard(
                  pack: pack1,
                  canAfford: _canAfford(pack1),
                  onTap: () => _buyPack(pack1),
                ),
              ),
              const SizedBox(width: 12),
              if (pack2 != null)
                Expanded(
                  child: _StoreGridPackCard(
                    pack: pack2,
                    canAfford: _canAfford(pack2),
                    onTap: () => _buyPack(pack2),
                  ),
                )
              else
                const Expanded(child: SizedBox()),
            ],
          ),
        ),
      );

      if (i + 2 < packs.length) {
        rows.add(const SizedBox(height: 12));
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }

  // ---------------------------------------------------------------------------
  // VIP PERKS CLUB STRIP
  // ---------------------------------------------------------------------------
  Widget _buildVipClubStrip() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF220A45),
            Color(0xFF0F0324),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.6),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF080114),
            offset: Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.stars_rounded, color: AppColors.gold, size: 20),
              const SizedBox(width: 8),
              const Text(
                'COSMIC VIP CLUB',
                style: TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.teal, width: 0.8),
                ),
                child: Text(
                  'TIER ${widget.wallet.level}',
                  style: const TextStyle(
                    color: AppColors.teal,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'All vault claims grant VIP XP! Higher tiers permanently increase your daily bonus multipliers and unlock exclusive high-roller slot limits.',
            style: TextStyle(
              color: AppColors.textDim,
              fontSize: 11.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          // Progress to next tier
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: widget.wallet.levelProgress.clamp(0.05, 1.0),
              minHeight: 7,
              backgroundColor: const Color(0xFF100525),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
            ),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Level ${widget.wallet.level}',
                style: const TextStyle(
                  color: AppColors.textDim,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Level ${widget.wallet.level + 1}',
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 2-COLUMN STORE PACK CARD
// -----------------------------------------------------------------------------
class _StoreGridPackCard extends StatelessWidget {
  final StorePack pack;
  final bool canAfford;
  final VoidCallback onTap;

  const _StoreGridPackCard({
    required this.pack,
    required this.canAfford,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isGem = pack.category == StoreCategory.gems;
    final borderColor = pack.isHighRoller
        ? AppColors.gold
        : isGem
            ? AppColors.teal.withValues(alpha: 0.6)
            : AppColors.gold.withValues(alpha: 0.45);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: pack.isHighRoller
              ? const [Color(0xFF381363), Color(0xFF1A0636), Color(0xFF100324)]
              : const [Color(0xFF230D45), Color(0xFF16062E), Color(0xFF0F0320)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: pack.isHighRoller ? 1.6 : 1.2),
        boxShadow: [
          // 2.5D solid extruded bottom
          const BoxShadow(
            color: Color(0xFF070014),
            offset: Offset(0, 4),
            blurRadius: 0,
          ),
          // Glow
          if (pack.isHighRoller)
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Stack(
        children: [
          // Radial aura behind asset
          Positioned(
            top: 26,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isGem ? AppColors.teal : AppColors.gold)
                      .withValues(alpha: 0.12),
                ),
              ),
            ),
          ),

          // Main vertical column
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Top Tag Bar: Multiplier Pill or XP
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Badge (POPULAR / HOT DEAL / BEST VALUE)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: pack.badgeColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: pack.badgeColor.withValues(alpha: 0.8),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        pack.badge,
                        style: TextStyle(
                          color: pack.badgeColor,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),

                    if (pack.valueMultiplier != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          pack.valueMultiplier!,
                          style: const TextStyle(
                            color: AppColors.gold,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 8),

                // 3D Visual Center Art
                SizedBox(
                  height: 58,
                  child: Image.asset(
                    pack.asset,
                    fit: BoxFit.contain,
                  ),
                ),

                const SizedBox(height: 8),

                // Pack Title (Bold, never truncated)
                Text(
                  pack.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.2,
                  ),
                ),

                const SizedBox(height: 3),

                // Primary Reward Amount
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      isGem
                          ? 'assets/images/currency/gem.png'
                          : 'assets/images/currency/coin.png',
                      width: 14,
                      height: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isGem
                          ? '+${pack.gems}'
                          : '+${CurrencyBar.format(pack.coins)}',
                      style: TextStyle(
                        color: isGem ? AppColors.teal : AppColors.gold,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 2),
                Text(
                  '+${pack.xp} XP',
                  style: const TextStyle(
                    color: AppColors.textDim,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),

                const SizedBox(height: 8),

                // Price tag (paid in the OTHER currency — a real sink).
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      pack.paidInGems
                          ? 'assets/images/currency/gem.png'
                          : 'assets/images/currency/coin.png',
                      width: 13,
                      height: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      pack.paidInGems
                          ? '${pack.costGems}'
                          : CurrencyBar.format(pack.costCoins),
                      style: TextStyle(
                        color: canAfford ? Colors.white : const Color(0xFFFF8A80),
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // 2.5D Chunky Action Button
                CosmicButton(
                  label: canAfford ? pack.cta : 'NEED MORE',
                  height: 36,
                  width: double.infinity,
                  fontSize: 11.5,
                  gradient: canAfford
                      ? pack.buttonGradient
                      : const LinearGradient(
                          colors: [Color(0xFF3A3A3A), Color(0xFF222222)]),
                  onTap: onTap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// VAULT REWARD MODAL (UNBOXING CELEBRATION)
// -----------------------------------------------------------------------------
class _VaultRewardDialog extends StatelessWidget {
  final String title;
  final String packName;
  final int coins;
  final int gems;
  final int xp;
  final String iconAsset;
  final VoidCallback onCollect;

  const _VaultRewardDialog({
    required this.title,
    required this.packName,
    required this.coins,
    required this.gems,
    required this.xp,
    required this.iconAsset,
    required this.onCollect,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 320,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF381468),
                Color(0xFF1E073D),
                Color(0xFF100224),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.gold, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.9),
                offset: const Offset(0, 8),
                blurRadius: 20,
              ),
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.4),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Rotating background sunburst
                Positioned(
                  top: 20,
                  width: 260,
                  height: 260,
                  child: CustomPaint(
                    painter: _SunburstRaysPainter(
                      color: AppColors.gold.withValues(alpha: 0.12),
                      spokeCount: 18,
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Golden Stamped Title
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          letterSpacing: 1.2,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              offset: Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        packName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Large Glowing Hero Art
                      Image.asset(
                        iconAsset,
                        width: 90,
                        height: 90,
                      ),

                      const SizedBox(height: 18),

                      // Reward Cards Breakdown
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            if (coins > 0)
                              _rewardRow(
                                'assets/images/currency/coin.png',
                                '+${CurrencyBar.format(coins)} COINS',
                                AppColors.gold,
                              ),
                            if (gems > 0) ...[
                              if (coins > 0) const SizedBox(height: 6),
                              _rewardRow(
                                'assets/images/currency/gem.png',
                                '+$gems GEMS',
                                AppColors.teal,
                              ),
                            ],
                            if (xp > 0) ...[
                              const SizedBox(height: 6),
                              _rewardRow(
                                null,
                                '+$xp VIP XP',
                                const Color(0xFFFFD54F),
                                customIcon: Icons.stars_rounded,
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Chunky Collect Button
                      CosmicButton(
                        label: 'COLLECT & PLAY',
                        height: 48,
                        width: double.infinity,
                        fontSize: 14,
                        onTap: onCollect,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _rewardRow(String? asset, String label, Color color,
      {IconData? customIcon}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (asset != null)
          Image.asset(asset, width: 20, height: 20)
        else if (customIcon != null)
          Icon(customIcon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 14.5,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// CUSTOM SUNBURST PAINTER
// -----------------------------------------------------------------------------
class _SunburstRaysPainter extends CustomPainter {
  final Color color;
  final int spokeCount;

  _SunburstRaysPainter({
    required this.color,
    this.spokeCount = 12,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.max(size.width, size.height);
    final angleStep = (2 * math.pi) / spokeCount;

    for (int i = 0; i < spokeCount; i += 2) {
      final path = Path();
      final a1 = i * angleStep;
      final a2 = (i + 1) * angleStep;

      path.moveTo(center.dx, center.dy);
      path.lineTo(
        center.dx + radius * math.cos(a1),
        center.dy + radius * math.sin(a1),
      );
      path.lineTo(
        center.dx + radius * math.cos(a2),
        center.dy + radius * math.sin(a2),
      );
      path.close();

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SunburstRaysPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.spokeCount != spokeCount;
}
