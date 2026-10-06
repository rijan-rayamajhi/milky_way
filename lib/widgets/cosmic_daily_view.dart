import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/engagement_service.dart';
import '../services/real_play_service.dart';
import '../services/sound_service.dart';
import '../services/wallet_service.dart';
import '../theme/app_theme.dart';
import 'cosmic_button.dart';
import 'currency_bar.dart';

/// Production-ready AAA Game Daily Rewards & Interactive Lucky Wheel Console.
class CosmicDailyView extends StatefulWidget {
  final WalletService wallet;
  final EngagementService engagement;

  const CosmicDailyView({
    super.key,
    required this.wallet,
    required this.engagement,
  });

  @override
  State<CosmicDailyView> createState() => _CosmicDailyViewState();
}

class _CosmicDailyViewState extends State<CosmicDailyView>
    with TickerProviderStateMixin {
  late final AnimationController _wheelController;
  late final AnimationController _pulseController;
  late final AnimationController _tickerFlutterController;
  late final AnimationController _sunburstController;

  Timer? _secondTimer;
  bool _isSpinning = false;
  double _wheelRotation = 0.0;
  double _targetRotation = 0.0;

  EngagementService get eng => widget.engagement;

  @override
  void initState() {
    super.initState();

    // Wheel spin deceleration controller
    _wheelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    // Subtle background sunburst rotation
    _sunburstController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    // Breathing pulse for claimable buttons and neon lights
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    // Ticker flutter animation when wheel spins
    _tickerFlutterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
    );

    // Tick every second to update hourly countdown and reset timer
    _secondTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _wheelController.dispose();
    _sunburstController.dispose();
    _pulseController.dispose();
    _tickerFlutterController.dispose();
    _secondTimer?.cancel();
    super.dispose();
  }

  Duration get _timeUntilMidnightReset {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return tomorrow.difference(now);
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  void _spinWheel() {
    if (!eng.canSpinWheel || _isSpinning) return;

    // Decide the (random, weighted) outcome up front, then land the wheel on it.
    final result = eng.spinDailyWheel(widget.wallet);
    if (result == null) return;

    setState(() => _isSpinning = true);
    sound.spinStart();

    const twoPi = 2 * math.pi;
    final seg = twoPi / EngagementService.wheelSegments.length;
    // Segment `index` is drawn centered at the top; to park it under the needle
    // the wheel must rotate to a multiple of 2π minus index*seg.
    final align = (-result.index * seg) % twoPi;
    final completed = (_wheelRotation / twoPi).floor();
    const fullSpins = 6;
    _targetRotation = (completed + fullSpins) * twoPi + align;
    while (_targetRotation <= _wheelRotation + math.pi) {
      _targetRotation += twoPi;
    }

    final startRotation = _wheelRotation;
    _tickerFlutterController.repeat(reverse: true);

    _wheelController.reset();
    final animation = CurvedAnimation(
      parent: _wheelController,
      curve: Curves.easeOutCubic,
    );
    animation.addListener(() {
      setState(() {
        _wheelRotation =
            startRotation + (_targetRotation - startRotation) * animation.value;
      });
    });

    _wheelController.forward().then((_) {
      _tickerFlutterController.stop();
      _tickerFlutterController.reset();
      sound.spinStop();
      sound.bigWin();
      setState(() => _isSpinning = false);
      _showWheelPrizeModal(result.prize);
    });
  }

  void _claimStreak() {
    final day = eng.nextStreakDay;
    final reward = eng.claimDaily(widget.wallet);
    if (reward != null) {
      sound.win();
      _showRewardModal(day: day, coins: reward.coins, gems: reward.gems);
    }
  }

  void _showWheelPrizeModal(WheelPrize prize) {
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
        return _DailyRewardCelebrationDialog(
          day: 1, // shows the wheel art
          title: 'WHEEL PRIZE!',
          subtitle: 'The Lucky Wheel landed on ${prize.label}',
          coins: prize.coins,
          gems: prize.gems,
          onCollect: () => Navigator.of(context).pop(),
        );
      },
    );
  }

  void _claimHourly() {
    if (eng.claimHourly(widget.wallet)) {
      sound.win();
      _showHourlyModal();
    }
  }

  void _showRewardModal({
    required int day,
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
        return _DailyRewardCelebrationDialog(
          day: day,
          coins: coins,
          gems: gems,
          onCollect: () => Navigator.of(context).pop(),
        );
      },
    );
  }

  void _showHourlyModal() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.8),
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, anim, secAnim, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return ScaleTransition(scale: curved, child: child);
      },
      pageBuilder: (context, anim1, anim2) {
        return _DailyRewardCelebrationDialog(
          day: 0,
          title: 'STAR DROP HARVESTED!',
          subtitle: 'Hourly Celestial Bonus Collected',
          coins: EngagementService.hourlyCoins,
          gems: 0,
          onCollect: () => Navigator.of(context).pop(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: eng,
      builder: (context, _) {
        final canClaim = eng.canClaimDaily;
        final nextDay = eng.nextStreakDay;
        final currentStreak = eng.currentStreakDay;

        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 115),
          children: [
            // 1. Ornate Header with Streak Flame
            _buildDailyHeader(currentStreak),

            const SizedBox(height: 14),

            // 2. Interactive Lucky Spin Wheel Console (The Hero Event)
            _buildLuckyWheelConsole(eng.canSpinWheel),

            const SizedBox(height: 16),

            // 3. Hourly Celestial Star Drop Reactor
            _buildHourlyReactorCard(),

            const SizedBox(height: 18),

            // 4. Daily Missions
            _buildMissionsSection(),

            const SizedBox(height: 18),

            // 5. 7-Day Grand Streak Ladder
            _buildStreakLadderSection(canClaim, nextDay, currentStreak),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 1. DAILY HEADER
  // ---------------------------------------------------------------------------
  Widget _buildDailyHeader(int streak) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2E1156),
            Color(0xFF14052A),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.6),
          width: 1.4,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF070014),
            offset: Offset(0, 4),
            blurRadius: 0,
          ),
          BoxShadow(
            color: Color(0x33FFD700),
            offset: Offset(0, 2),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          // Golden star crest
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppColors.goldGradient,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFFF3B0), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.45),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Icon(
              Icons.stars_rounded,
              color: Color(0xFF1B0733),
              size: 26,
            ),
          ),
          const SizedBox(width: 12),

          // Title & Subtitle
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'DAILY REWARDS',
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
                    SizedBox(width: 4),
                    Icon(Icons.auto_awesome, color: AppColors.gold, size: 14),
                  ],
                ),
                SizedBox(height: 2),
                Text(
                  'Spin the Lucky Wheel & Advance Streak',
                  style: TextStyle(
                    color: AppColors.textDim,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Streak Flame Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF3D00), Color(0xFFFF9100)],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFFF9C4), width: 1.2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66FF3D00),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_fire_department_rounded,
                    color: Colors.white, size: 14),
                const SizedBox(width: 3),
                Text(
                  'DAY $streak/7',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 10.5,
                    letterSpacing: 0.3,
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
  // 2. LUCKY SPIN WHEEL CONSOLE (INTERACTIVE ARCADE STAGE)
  // ---------------------------------------------------------------------------
  Widget _buildLuckyWheelConsole(bool canSpin) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: canSpin ? AppColors.gold : AppColors.purple.withValues(alpha: 0.7),
          width: 1.8,
        ),
        boxShadow: [
          const BoxShadow(
            color: Color(0xFF070014),
            offset: Offset(0, 5),
            blurRadius: 0,
          ),
          if (canSpin)
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.35),
              blurRadius: 18,
              spreadRadius: 1,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background cosmic gradient
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF3B1368),
                    Color(0xFF1E073B),
                    Color(0xFF110324),
                  ],
                ),
              ),
            ),

            // Rotating Sunburst rays background
            Positioned(
              top: 10,
              width: 320,
              height: 320,
              child: AnimatedBuilder(
                animation: _sunburstController,
                builder: (context, _) => Transform.rotate(
                  angle: _sunburstController.value * 2 * math.pi,
                  child: CustomPaint(
                    painter: _WheelSunburstPainter(
                      color: AppColors.gold.withValues(alpha: 0.08),
                      spokeCount: 18,
                    ),
                  ),
                ),
              ),
            ),

            // Top Status Bar: Day indicator or reset countdown
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: canSpin
                        ? [
                            const Color(0xFFFFB300),
                            const Color(0xFFE65100),
                          ]
                        : [
                            const Color(0xFF4A148C),
                            const Color(0xFF1A0033),
                          ],
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      canSpin
                          ? Icons.casino_rounded
                          : Icons.timer_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      canSpin
                          ? '🌟 FREE SPIN READY!'
                          : 'NEXT WHEEL RESET IN:',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 10.5,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    if (!canSpin)
                      Text(
                        _formatDuration(_timeUntilMidnightReset),
                        style: const TextStyle(
                          color: Color(0xFFFFF176),
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'READY',
                          style: TextStyle(
                            color: Color(0xFFFFF176),
                            fontWeight: FontWeight.w900,
                            fontSize: 9.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Main Content Area: The Wheel & Controls
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 40, 16, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 4),

                  // Title Callout
                  const Text(
                    'LUCKY SPIN WHEEL',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 19,
                      letterSpacing: 0.8,
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          offset: Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    canSpin
                        ? 'Spin to win a random cosmic prize!'
                        : 'Spun today! Return tomorrow for another free spin.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textDim,
                      fontSize: 12,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // THE INTERACTIVE WHEEL STAGE
                  SizedBox(
                    width: 175,
                    height: 175,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        // Outer glowing neon rim
                        Container(
                          width: 170,
                          height: 170,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: canSpin
                                  ? AppColors.gold.withValues(alpha: 0.6)
                                  : AppColors.purple.withValues(alpha: 0.4),
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (canSpin
                                        ? AppColors.gold
                                        : AppColors.purple)
                                    .withValues(alpha: 0.4),
                                blurRadius: 18,
                              ),
                            ],
                          ),
                        ),

                        // The real segmented wheel — lands on the won wedge.
                        Transform.rotate(
                          angle: _wheelRotation,
                          child: CustomPaint(
                            size: const Size(158, 158),
                            painter: _LuckyWheelPainter(
                                EngagementService.wheelSegments),
                          ),
                        ),

                        // Center gem cap
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.goldGradient,
                            border: Border.all(color: Colors.white, width: 1.5),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black54,
                                offset: Offset(0, 2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.stars_rounded,
                            size: 16,
                            color: Color(0xFF1B0733),
                          ),
                        ),

                        // Top Golden Ticker Needle
                        Positioned(
                          top: -6,
                          child: AnimatedBuilder(
                            animation: _tickerFlutterController,
                            builder: (context, child) {
                              final wobble = math.sin(
                                      _tickerFlutterController.value *
                                          math.pi *
                                          2) *
                                  0.12;
                              return Transform.rotate(
                                angle: wobble,
                                child: child,
                              );
                            },
                            child: CustomPaint(
                              size: const Size(20, 24),
                              painter: _TickerNeedlePainter(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Spin Action Button
                  CosmicButton(
                    label: _isSpinning
                        ? 'SPINNING...'
                        : canSpin
                            ? 'SPIN LUCKY WHEEL'
                            : 'COME BACK TOMORROW',
                    icon: _isSpinning
                        ? null
                        : canSpin
                            ? Icons.casino_rounded
                            : Icons.lock_clock_rounded,
                    height: 48,
                    width: double.infinity,
                    fontSize: 14,
                    gradient: canSpin
                        ? AppColors.goldGradient
                        : const LinearGradient(
                            colors: [Color(0xFF424242), Color(0xFF212121)],
                          ),
                    onTap: canSpin && !_isSpinning ? _spinWheel : null,
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
  // 3. HOURLY CELESTIAL STAR DROP REACTOR
  // ---------------------------------------------------------------------------
  Widget _buildHourlyReactorCard() {
    final canClaim = eng.canClaimHourly;
    final remaining = eng.hourlyRemaining;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1D0E42),
            Color(0xFF0F0426),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: canClaim ? AppColors.teal : AppColors.teal.withValues(alpha: 0.35),
          width: 1.3,
        ),
        boxShadow: [
          const BoxShadow(
            color: Color(0xFF060012),
            offset: Offset(0, 4),
            blurRadius: 0,
          ),
          if (canClaim)
            BoxShadow(
              color: AppColors.teal.withValues(alpha: 0.3),
              blurRadius: 12,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Row(
        children: [
          // Hourglass / Star Reactor Icon with glowing pulse
          Stack(
            alignment: Alignment.center,
            children: [
              if (canClaim)
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) => Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.teal.withValues(
                        alpha: 0.15 + _pulseController.value * 0.18,
                      ),
                    ),
                  ),
                ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.teal.withValues(alpha: 0.18),
                  border: Border.all(
                    color: canClaim ? AppColors.teal : Colors.white24,
                    width: 1.2,
                  ),
                ),
                child: Icon(
                  Icons.timer_rounded,
                  color: canClaim ? AppColors.teal : AppColors.textDim,
                  size: 24,
                ),
              ),
            ],
          ),

          const SizedBox(width: 12),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text(
                      'HOURLY STAR DROP',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(width: 5),
                    if (canClaim)
                      const Icon(Icons.stars, color: AppColors.gold, size: 13),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  canClaim
                      ? '🪙 1,000 Coins ready to collect!'
                      : 'Next drop in ${_formatDuration(remaining)}',
                  style: TextStyle(
                    color: canClaim ? AppColors.gold : AppColors.textDim,
                    fontSize: 12,
                    fontWeight: canClaim ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Action Button
          CosmicButton(
            label: canClaim ? 'CLAIM' : _formatDuration(remaining),
            height: 38,
            width: canClaim ? 82 : 88,
            fontSize: canClaim ? 12 : 11,
            gradient: canClaim
                ? const LinearGradient(
                    colors: [Color(0xFF26E0D8), Color(0xFF009688)],
                  )
                : const LinearGradient(
                    colors: [Color(0xFF37474F), Color(0xFF263238)],
                  ),
            onTap: canClaim ? _claimHourly : null,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. 7-DAY STREAK LADDER SECTION
  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------
  // DAILY MISSIONS
  // ---------------------------------------------------------------------------
  IconData _missionIcon(MissionType t) {
    switch (t) {
      case MissionType.spins:
        return Icons.casino_rounded;
      case MissionType.winCoins:
        return Icons.monetization_on_rounded;
      case MissionType.bigWins:
        return Icons.local_fire_department_rounded;
      case MissionType.playGames:
        return Icons.sports_esports_rounded;
    }
  }

  void _claimMission(int slot) {
    if (eng.claimMission(widget.wallet, slot)) {
      sound.win();
    }
  }

  Widget _buildMissionsSection() {
    final missions = eng.missions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.flag_rounded, color: AppColors.gold, size: 18),
            const SizedBox(width: 6),
            const Text(
              'DAILY MISSIONS',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 0.6,
              ),
            ),
            const Spacer(),
            Text(
              'RESETS ${_formatDuration(_timeUntilMidnightReset)}',
              style: const TextStyle(
                color: AppColors.textDim,
                fontWeight: FontWeight.w700,
                fontSize: 10,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final m in missions) ...[
          _buildMissionCard(m),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildMissionCard(Mission m) {
    final color = m.claimable
        ? AppColors.gold
        : m.claimed
            ? AppColors.teal
            : AppColors.purple;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF221049), Color(0xFF120428)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.2),
        boxShadow: const [
          BoxShadow(color: Color(0xFF060012), offset: Offset(0, 3), blurRadius: 0),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.18),
              border: Border.all(color: color.withValues(alpha: 0.6), width: 1),
            ),
            child: Icon(_missionIcon(m.type), color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  m.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: m.fraction,
                    minHeight: 6,
                    backgroundColor: const Color(0xFF0C031E),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${m.progress}/${m.target}',
                      style: const TextStyle(
                        color: AppColors.textDim,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Image.asset('assets/images/currency/coin.png',
                        width: 11, height: 11),
                    const SizedBox(width: 2),
                    Text(
                      CurrencyBar.format(m.rewardCoins),
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (m.rewardGems > 0) ...[
                      const SizedBox(width: 6),
                      Image.asset('assets/images/currency/gem.png',
                          width: 10, height: 10),
                      const SizedBox(width: 2),
                      Text(
                        '${m.rewardGems}',
                        style: const TextStyle(
                          color: AppColors.teal,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 68,
            child: CosmicButton(
              label: m.claimed
                  ? 'DONE'
                  : m.claimable
                      ? 'CLAIM'
                      : '${(m.fraction * 100).toInt()}%',
              height: 34,
              fontSize: 10.5,
              gradient: m.claimable
                  ? AppColors.goldGradient
                  : const LinearGradient(
                      colors: [Color(0xFF37474F), Color(0xFF263238)]),
              onTap: m.claimable ? () => _claimMission(m.slot) : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakLadderSection(
      bool canClaim, int nextDay, int currentStreak) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.military_tech_rounded,
                color: AppColors.gold, size: 18),
            const SizedBox(width: 6),
            const Text(
              '7-DAY STREAK LADDER',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 0.6,
              ),
            ),
            const Spacer(),
            Text(
              'DAY $currentStreak OF 7',
              style: const TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Claim today's streak reward (separate from the Lucky Wheel).
        CosmicButton(
          label: canClaim ? 'CLAIM DAY $nextDay STREAK' : 'STREAK CLAIMED TODAY',
          icon: canClaim ? Icons.redeem_rounded : Icons.check_circle_rounded,
          height: 44,
          width: double.infinity,
          fontSize: 13,
          gradient: canClaim
              ? AppColors.goldGradient
              : const LinearGradient(
                  colors: [Color(0xFF424242), Color(0xFF212121)]),
          onTap: canClaim ? _claimStreak : null,
        ),

        const SizedBox(height: 12),

        // Days 1 through 6 in tight responsive Rows (eliminates GridView media-padding gap)
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _buildLadderDayCard(
                    reward: EngagementService.ladder[i],
                    canClaim: canClaim,
                    nextDay: nextDay,
                    currentStreak: currentStreak,
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 8),

        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 3; i < 6; i++) ...[
                if (i > 3) const SizedBox(width: 8),
                Expanded(
                  child: _buildLadderDayCard(
                    reward: EngagementService.ladder[i],
                    canClaim: canClaim,
                    nextDay: nextDay,
                    currentStreak: currentStreak,
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Day 7: The Grand Apex Vault (Full-Width Hero Card!)
        _buildDay7GrandApexCard(
          reward: EngagementService.ladder[6],
          canClaim: canClaim,
          nextDay: nextDay,
          currentStreak: currentStreak,
        ),
      ],
    );
  }

  Widget _buildLadderDayCard({
    required DailyReward reward,
    required bool canClaim,
    required int nextDay,
    required int currentStreak,
  }) {
    final isToday = canClaim && reward.day == nextDay;
    final isClaimed =
        reward.day < nextDay || (!canClaim && reward.day <= currentStreak);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isToday
              ? [const Color(0xFF4A1875), const Color(0xFF260A44)]
              : isClaimed
                  ? [const Color(0xFF1E1038), const Color(0xFF0F0620)]
                  : [const Color(0xFF200C40), const Color(0xFF120428)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isToday
              ? AppColors.gold
              : isClaimed
                  ? AppColors.teal.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.15),
          width: isToday ? 1.8 : 1.0,
        ),
        boxShadow: [
          const BoxShadow(
            color: Color(0xFF060012),
            offset: Offset(0, 3),
            blurRadius: 0,
          ),
          if (isToday)
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Day Title
                Text(
                  'DAY ${reward.day}',
                  style: TextStyle(
                    color: isToday
                        ? AppColors.gold
                        : isClaimed
                            ? AppColors.teal
                            : AppColors.textDim,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 4),

                // Icon
                Image.asset(
                  reward.gems > 0
                      ? 'assets/images/currency/gem.png'
                      : 'assets/images/currency/coin.png',
                  width: 22,
                  height: 22,
                ),

                const SizedBox(height: 4),

                // Amount
                Text(
                  CurrencyBar.format(reward.coins),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),

                if (reward.gems > 0)
                  Text(
                    '+${reward.gems} Gems',
                    style: const TextStyle(
                      color: AppColors.teal,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                else
                  const SizedBox(height: 12),
              ],
            ),
          ),

          // Status Badge / Overlay
          if (isClaimed)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.teal,
                ),
                child: const Icon(Icons.check, size: 10, color: Colors.black),
              ),
            )
          else if (isToday)
            Positioned(
              top: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  gradient: AppColors.goldGradient,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(5),
                  ),
                ),
                child: const Text(
                  'TODAY',
                  style: TextStyle(
                    color: Color(0xFF1B0733),
                    fontSize: 7.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DAY 7 GRAND APEX VAULT CARD
  // ---------------------------------------------------------------------------
  Widget _buildDay7GrandApexCard({
    required DailyReward reward,
    required bool canClaim,
    required int nextDay,
    required int currentStreak,
  }) {
    final isToday = canClaim && reward.day == nextDay;
    final isClaimed =
        reward.day < nextDay || (!canClaim && reward.day <= currentStreak);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isToday
              ? [const Color(0xFF5D1E8F), const Color(0xFF280B4A)]
              : [const Color(0xFF30115E), const Color(0xFF160630)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isToday
              ? AppColors.gold
              : AppColors.gold.withValues(alpha: 0.6),
          width: isToday ? 2.0 : 1.4,
        ),
        boxShadow: [
          const BoxShadow(
            color: Color(0xFF070014),
            offset: Offset(0, 4),
            blurRadius: 0,
          ),
          BoxShadow(
            color: AppColors.gold.withValues(alpha: isToday ? 0.35 : 0.18),
            blurRadius: 14,
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
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold.withValues(alpha: 0.18),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.3),
                      blurRadius: 14,
                    ),
                  ],
                ),
              ),
              Image.asset(
                'assets/images/engagement/reward_chest.png',
                width: 56,
              ),
            ],
          ),

          const SizedBox(width: 14),

          // Day 7 Grand Apex Title & Rewards
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
                        gradient: AppColors.goldGradient,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'DAY 7 • GRAND PRIZE',
                        style: TextStyle(
                          color: Color(0xFF1C0835),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (isClaimed)
                      const Text(
                        'COMPLETED',
                        style: TextStyle(
                          color: AppColors.teal,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'APEX COSMIC VAULT',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14.5,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Image.asset('assets/images/currency/coin.png',
                        width: 15, height: 15),
                    const SizedBox(width: 4),
                    const Text(
                      '+50,000 Coins',
                      style: TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w900,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Image.asset('assets/images/currency/gem.png',
                        width: 13, height: 13),
                    const SizedBox(width: 3),
                    const Text(
                      '+5 Gems',
                      style: TextStyle(
                        color: AppColors.teal,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ],
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
// WHEEL SUNBURST PAINTER
// -----------------------------------------------------------------------------
class _WheelSunburstPainter extends CustomPainter {
  final Color color;
  final int spokeCount;

  _WheelSunburstPainter({
    required this.color,
    this.spokeCount = 16,
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
  bool shouldRepaint(covariant _WheelSunburstPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.spokeCount != spokeCount;
}

// -----------------------------------------------------------------------------
// TOP TICKER NEEDLE PAINTER
// -----------------------------------------------------------------------------
class _TickerNeedlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    path.moveTo(size.width / 2, size.height); // bottom tip pointing down
    path.lineTo(0, 0); // top left
    path.lineTo(size.width, 0); // top right
    path.close();

    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFF9C4), Color(0xFFFFB300), Color(0xFFE65100)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path.shift(const Offset(0, 2)), shadowPaint);
    canvas.drawPath(path, paint);

    // Border
    final borderPaint = Paint()
      ..color = const Color(0xFFFFFDE7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// -----------------------------------------------------------------------------
// DAILY REWARD CELEBRATION DIALOG
// -----------------------------------------------------------------------------
class _DailyRewardCelebrationDialog extends StatelessWidget {
  final int day;
  final String? title;
  final String? subtitle;
  final int coins;
  final int gems;
  final VoidCallback onCollect;

  const _DailyRewardCelebrationDialog({
    required this.day,
    this.title,
    this.subtitle,
    required this.coins,
    required this.gems,
    required this.onCollect,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTitle = title ?? 'WHEEL REWARD UNLOCKED!';
    final effectiveSubtitle = subtitle ?? 'Day $day Streak Bonus Claimed';

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
                color: AppColors.gold.withValues(alpha: 0.45),
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
                    effectiveTitle,
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
                    effectiveSubtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Image.asset(
                    day > 0
                        ? 'assets/images/engagement/daily_wheel.png'
                        : 'assets/images/engagement/reward_chest.png',
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
                  const SizedBox(height: 18),
                  CosmicButton(
                    label: 'COLLECT & PLAY',
                    height: 48,
                    width: double.infinity,
                    fontSize: 14,
                    onTap: onCollect,
                  ),
                  const SizedBox(height: 14),
                  // Real Money Free Spins Banner
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      sound.win();
                      RealPlayService.openRealPlay();
                      onCollect();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF381503), Color(0xFF1E0800)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFFFB300),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFFFFD54F), Color(0xFFFF8F00)],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.stars_rounded,
                              color: Color(0xFF2E1200),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'CLAIM 100 REAL CASH SPINS',
                                  style: TextStyle(
                                    color: Color(0xFFFFD54F),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                SizedBox(height: 1),
                                Text(
                                  '100% Match Bonus on SpinnerLog',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Color(0xFFFFD54F),
                            size: 13,
                          ),
                        ],
                      ),
                    ),
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

// -----------------------------------------------------------------------------
// LUCKY WHEEL PAINTER — real segmented wheel; segment 0 is centered at the top,
// so the spin math in _spinWheel can park any wedge under the needle.
// -----------------------------------------------------------------------------
class _LuckyWheelPainter extends CustomPainter {
  final List<WheelPrize> segments;
  _LuckyWheelPainter(this.segments);

  static const _fills = [
    Color(0xFF6A2DB5),
    Color(0xFF2A1A5E),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: r);
    final n = segments.length;
    final seg = 2 * math.pi / n;
    final start0 = -math.pi / 2 - seg / 2; // segment 0 centered at top

    for (var i = 0; i < n; i++) {
      final startAngle = start0 + i * seg;
      final wedge = Paint()
        ..style = PaintingStyle.fill
        ..color = _fills[i % _fills.length];
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(rect, startAngle, seg, false)
        ..close();
      canvas.drawPath(path, wedge);

      // Divider spoke.
      final spoke = Paint()
        ..color = const Color(0x55FFD54F)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, spoke);

      // Label (upright, short text).
      final labelAngle = -math.pi / 2 + i * seg;
      final pos = Offset(
        center.dx + math.cos(labelAngle) * r * 0.62,
        center.dy + math.sin(labelAngle) * r * 0.62,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: segments[i].label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 8.5,
            fontWeight: FontWeight.w900,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: r * 0.8);
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }

    // Outer ring.
    canvas.drawCircle(
      center,
      r - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFFFC73B),
    );
  }

  @override
  bool shouldRepaint(covariant _LuckyWheelPainter oldDelegate) =>
      oldDelegate.segments != segments;
}
