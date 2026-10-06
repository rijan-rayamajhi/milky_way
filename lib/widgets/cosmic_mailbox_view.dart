import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/engagement_service.dart';
import '../services/sound_service.dart';
import '../services/wallet_service.dart';
import '../theme/app_theme.dart';
import 'cosmic_button.dart';
import 'currency_bar.dart';

/// Production-ready AAA Game Inbox & Classified Airdrop Terminal.
class CosmicMailboxView extends StatefulWidget {
  final WalletService wallet;
  final EngagementService engagement;
  final VoidCallback onGoToLobby;

  const CosmicMailboxView({
    super.key,
    required this.wallet,
    required this.engagement,
    required this.onGoToLobby,
  });

  @override
  State<CosmicMailboxView> createState() => _CosmicMailboxViewState();
}

class _CosmicMailboxViewState extends State<CosmicMailboxView>
    with TickerProviderStateMixin {
  late final AnimationController _radarController;
  late final AnimationController _floatController;
  late final AnimationController _pulseController;

  EngagementService get eng => widget.engagement;

  @override
  void initState() {
    super.initState();
    // Continuous rotating radar sweep
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Floating bobbing motion for the empty state chest
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    // Breathing glow for buttons and beacons
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _radarController.dispose();
    _floatController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _claimSingleGift(Gift g) {
    eng.claimGift(widget.wallet, g.id);
    sound.win();
    _showGiftUnboxingModal(
      title: 'AIRDROP SECURED!',
      subtitle: g.title,
      coins: g.coins,
      gems: g.gems,
    );
  }

  void _claimAllGifts() {
    final gifts = List<Gift>.from(eng.mailbox);
    if (gifts.isEmpty) return;

    var totalCoins = 0;
    var totalGems = 0;
    for (final g in gifts) {
      totalCoins += g.coins;
      totalGems += g.gems;
    }

    eng.claimAll(widget.wallet);
    sound.bigWin();

    _showGiftUnboxingModal(
      title: 'ALL AIRDROPS CLAIMED!',
      subtitle: '${gifts.length} Classified Crates Opened',
      coins: totalCoins,
      gems: totalGems,
    );
  }

  void _showGiftUnboxingModal({
    required String title,
    required String subtitle,
    required int coins,
    required int gems,
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
        return _MailboxRewardDialog(
          title: title,
          subtitle: subtitle,
          coins: coins,
          gems: gems,
          onCollect: () => Navigator.of(context).pop(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([eng, widget.wallet]),
      builder: (context, _) {
        final gifts = eng.mailbox;

        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 115),
          children: [
            // 1. Quantum Comms Header Bar
            _buildTerminalHeader(gifts.length),

            const SizedBox(height: 14),

            // 2. Next Level Airdrop Milestone Preview Bar
            _buildNextMilestoneTracker(),

            const SizedBox(height: 16),

            // 3. Body: Either Gifts List or Jaw-dropping Empty State
            if (gifts.isNotEmpty) ...[
              _buildSectionTitle('PENDING TRANSMISSIONS (${gifts.length})'),
              const SizedBox(height: 10),
              for (final g in gifts) ...[
                _buildGiftCrateCard(g),
                const SizedBox(height: 12),
              ],
            ] else ...[
              _buildEmptyCommsTerminal(),
            ],
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 1. TERMINAL HEADER
  // ---------------------------------------------------------------------------
  Widget _buildTerminalHeader(int unreadCount) {
    final hasUnread = unreadCount > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2B1052),
            Color(0xFF130528),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasUnread
              ? AppColors.gold
              : AppColors.purple.withValues(alpha: 0.65),
          width: 1.4,
        ),
        boxShadow: [
          const BoxShadow(
            color: Color(0xFF070014),
            offset: Offset(0, 4),
            blurRadius: 0,
          ),
          if (hasUnread)
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.3),
              blurRadius: 12,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Row(
        children: [
          // Beacon radar crest with status dot
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: hasUnread
                      ? AppColors.goldGradient
                      : const LinearGradient(
                          colors: [Color(0xFF3E1D75), Color(0xFF200945)],
                        ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: hasUnread ? const Color(0xFFFFF3B0) : AppColors.teal,
                    width: 1.4,
                  ),
                ),
                child: Icon(
                  Icons.mark_email_unread_rounded,
                  color: hasUnread ? const Color(0xFF180630) : AppColors.teal,
                  size: 24,
                ),
              ),

              // Animated online status dot
              Positioned(
                top: 0,
                right: 0,
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) => Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hasUnread
                          ? const Color(0xFFFF1744)
                          : const Color(0xFF00E676),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: (hasUnread
                                  ? const Color(0xFFFF1744)
                                  : const Color(0xFF00E676))
                              .withValues(
                                  alpha: 0.5 + _pulseController.value * 0.4),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(width: 12),

          // Title & Status text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text(
                      'COSMIC INBOX',
                      style: TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
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
                    const Icon(Icons.wifi_tethering,
                        color: AppColors.teal, size: 14),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  hasUnread
                      ? '$unreadCount Classified Airdrop${unreadCount > 1 ? 's' : ''} Ready!'
                      : 'Orbital Frequencies Clear • Standing By',
                  style: TextStyle(
                    color: hasUnread ? AppColors.teal : AppColors.textDim,
                    fontSize: 11.5,
                    fontWeight:
                        hasUnread ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // "CLAIM ALL" button if unread exists, otherwise signal indicator
          if (hasUnread)
            CosmicButton(
              label: 'CLAIM ALL',
              height: 38,
              width: 90,
              fontSize: 11.5,
              onTap: _claimAllGifts,
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.teal.withValues(alpha: 0.4),
                  width: 0.8,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.satellite_alt_rounded,
                      color: AppColors.teal, size: 12),
                  SizedBox(width: 4),
                  Text(
                    'ONLINE',
                    style: TextStyle(
                      color: AppColors.teal,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      letterSpacing: 0.5,
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
  // 2. NEXT MILESTONE TRACKER GAUGE
  // ---------------------------------------------------------------------------
  Widget _buildNextMilestoneTracker() {
    final nextLvl = widget.wallet.level + 1;
    final rewardCoins = nextLvl * 500;
    final rewardGems = nextLvl % 5 == 0 ? 1 : 0;
    final progress = widget.wallet.levelProgress.clamp(0.02, 1.0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF220D45),
            Color(0xFF100324),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.teal.withValues(alpha: 0.45),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF060012),
            offset: Offset(0, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.rocket_launch_rounded,
                  color: AppColors.teal, size: 16),
              const SizedBox(width: 6),
              const Text(
                'NEXT AIRDROP RADAR',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'LVL $nextLvl CRATE',
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w900,
                    fontSize: 9.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Reach Level $nextLvl to dispatch +${CurrencyBar.format(rewardCoins)} Coins'
                  '${rewardGems > 0 ? " & +$rewardGems Gems" : ""} to your inbox!',
                  style: const TextStyle(
                    color: AppColors.textDim,
                    fontSize: 11,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: const Color(0xFF0C021C),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.teal),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(progress * 100).toInt()}% towards drop',
                style: const TextStyle(
                  color: AppColors.teal,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Level $nextLvl',
                style: const TextStyle(
                  color: AppColors.textDim,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3A. EMPTY STATE: JAW-DROPPING ORBITAL RADAR
  // ---------------------------------------------------------------------------
  Widget _buildEmptyCommsTerminal() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF2C1258),
            Color(0xFF170634),
            Color(0xFF0F0222),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.6),
          width: 1.4,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF070014),
            offset: Offset(0, 5),
            blurRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Animated Radar Sweep Waves Background
            Positioned(
              top: 10,
              width: 260,
              height: 260,
              child: AnimatedBuilder(
                animation: _radarController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _RadarSweepPainter(
                      sweepAngle: _radarController.value * 2 * math.pi,
                      radarColor: AppColors.teal.withValues(alpha: 0.22),
                    ),
                  );
                },
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Floating Levitating 3D Chest
                  AnimatedBuilder(
                    animation: _floatController,
                    builder: (context, child) {
                      final bob = math.sin(_floatController.value * math.pi) * 8;
                      return Transform.translate(
                        offset: Offset(0, -bob),
                        child: child,
                      );
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Soft glowing aura ring
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.gold.withValues(alpha: 0.16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.gold.withValues(alpha: 0.35),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                        ),
                        Image.asset(
                          'assets/images/engagement/reward_chest.png',
                          width: 86,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Stamped Game Title
                  const Text(
                    'Your Inbox is Clear',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      letterSpacing: 0.5,
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          offset: Offset(0, 2),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 6),

                  const Text(
                    'Level up on any slot machine or check back daily to receive classified gifts!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textDim,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Primary Arcade CTA
                  CosmicButton(
                    label: 'SPIN SLOTS NOW',
                    icon: Icons.sports_esports_rounded,
                    height: 46,
                    width: 220,
                    fontSize: 13,
                    onTap: widget.onGoToLobby,
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
  // 3B. GIFT CRATE CARDS (ACTIVE INBOX ITEMS)
  // ---------------------------------------------------------------------------
  Widget _buildGiftCrateCard(Gift g) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2E1258),
            Color(0xFF160630),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gold, width: 1.4),
        boxShadow: [
          const BoxShadow(
            color: Color(0xFF070014),
            offset: Offset(0, 4),
            blurRadius: 0,
          ),
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.25),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          // 3D Chest art with glowing backdrop
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold.withValues(alpha: 0.15),
                ),
              ),
              Image.asset(
                'assets/images/engagement/reward_chest.png',
                width: 46,
              ),
            ],
          ),

          const SizedBox(width: 12),

          // Gift Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: AppColors.teal.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.teal, width: 0.8),
                      ),
                      child: const Text(
                        'LEVEL REWARD',
                        style: TextStyle(
                          color: AppColors.teal,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Ready to open',
                      style: TextStyle(
                        color: AppColors.textDim,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  g.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Image.asset('assets/images/currency/coin.png',
                        width: 15, height: 15),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '+${CurrencyBar.format(g.coins)} Coins',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w900,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    if (g.gems > 0) ...[
                      const SizedBox(width: 8),
                      Image.asset('assets/images/currency/gem.png',
                          width: 13, height: 13),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          '+${g.gems} Gems',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.teal,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // 2.5D Claim Button
          CosmicButton(
            label: 'CLAIM',
            height: 38,
            width: 78,
            fontSize: 12,
            onTap: () => _claimSingleGift(g),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.gold,
        fontWeight: FontWeight.w900,
        fontSize: 13,
        letterSpacing: 0.8,
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// RADAR SWEEP PAINTER FOR EMPTY STATE
// -----------------------------------------------------------------------------
class _RadarSweepPainter extends CustomPainter {
  final double sweepAngle;
  final Color radarColor;

  _RadarSweepPainter({
    required this.sweepAngle,
    required this.radarColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Concentric range rings
    final ringPaint = Paint()
      ..color = radarColor.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (double r = radius * 0.25; r <= radius; r += radius * 0.25) {
      canvas.drawCircle(center, r, ringPaint);
    }

    // Crosshairs
    final linePaint = Paint()
      ..color = radarColor.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawLine(
        Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy), linePaint);
    canvas.drawLine(
        Offset(center.dx, center.dy - radius), Offset(center.dx, center.dy + radius), linePaint);

    // Rotating Radar Sweep Cone
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: math.pi / 2,
        colors: [
          radarColor.withValues(alpha: 0.4),
          radarColor.withValues(alpha: 0.0),
        ],
        transform: GradientRotation(sweepAngle),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, sweepPaint);

    // Rotating Sweep Leading Line
    final beamPaint = Paint()
      ..color = radarColor.withValues(alpha: 0.8)
      ..strokeWidth = 1.5;

    final tip = Offset(
      center.dx + radius * math.cos(sweepAngle),
      center.dy + radius * math.sin(sweepAngle),
    );
    canvas.drawLine(center, tip, beamPaint);
  }

  @override
  bool shouldRepaint(covariant _RadarSweepPainter oldDelegate) =>
      oldDelegate.sweepAngle != sweepAngle || oldDelegate.radarColor != radarColor;
}

// -----------------------------------------------------------------------------
// MAILBOX REWARD UNBOXING DIALOG
// -----------------------------------------------------------------------------
class _MailboxRewardDialog extends StatelessWidget {
  final String title;
  final String subtitle;
  final int coins;
  final int gems;
  final VoidCallback onCollect;

  const _MailboxRewardDialog({
    required this.title,
    required this.subtitle,
    required this.coins,
    required this.gems,
    required this.onCollect,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 310,
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w900,
                      fontSize: 21,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Image.asset(
                    'assets/images/engagement/reward_chest.png',
                    width: 90,
                    height: 90,
                  ),
                  const SizedBox(height: 18),
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset('assets/images/currency/coin.png',
                                  width: 20, height: 20),
                              const SizedBox(width: 8),
                              Text(
                                '+${CurrencyBar.format(coins)} COINS',
                                style: const TextStyle(
                                  color: AppColors.gold,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        if (gems > 0) ...[
                          if (coins > 0) const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset('assets/images/currency/gem.png',
                                  width: 18, height: 18),
                              const SizedBox(width: 8),
                              Text(
                                '+$gems GEMS',
                                style: const TextStyle(
                                  color: AppColors.teal,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  CosmicButton(
                    label: 'COLLECT & CONTINUE',
                    height: 48,
                    width: double.infinity,
                    fontSize: 13.5,
                    onTap: onCollect,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
