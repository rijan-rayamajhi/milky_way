import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/slot_game.dart';
import '../services/engagement_service.dart';
import '../services/sound_service.dart';
import '../services/wallet_service.dart';
import '../theme/app_theme.dart';
import 'currency_bar.dart';
import 'game_toast.dart';

/// Production-ready AAA Game Commander Profile, VIP Dossier & Audio Console.
class CosmicProfileView extends StatefulWidget {
  final WalletService wallet;
  final EngagementService engagement;

  const CosmicProfileView({
    super.key,
    required this.wallet,
    required this.engagement,
  });

  @override
  State<CosmicProfileView> createState() => _CosmicProfileViewState();
}

class _CosmicProfileViewState extends State<CosmicProfileView> {
  WalletService get wallet => widget.wallet;
  EngagementService get eng => widget.engagement;

  String get _vipTierTitle => wallet.vipTier.name;

  Color get _vipTierColor {
    switch (wallet.vipTierIndex) {
      case >= 5:
        return const Color(0xFFFF4081);
      case 4:
        return AppColors.gold;
      case 3:
        return AppColors.teal;
      case 2:
        return const Color(0xFF69F0AE);
      default:
        return Colors.white70;
    }
  }

  void _copyCallsign() {
    Clipboard.setData(const ClipboardData(text: '#MW-774921'));
    sound.tap();
    GameToast.show(
      context,
      title: 'CALLSIGN COPIED',
      message: 'Player ID #MW-774921 copied to clipboard!',
      icon: Icons.copy_rounded,
      accentColor: AppColors.teal,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([wallet, eng, sound]),
      builder: (context, _) {
        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 115),
          children: [
            // 1. Header: Commander Dossier
            _buildDossierHeader(),

            const SizedBox(height: 14),

            // 2. Holographic VIP Pilot Passport Card
            _buildHoloPassportCard(),

            const SizedBox(height: 16),

            // 3. Career Statistics Matrix (Hall of Fame)
            _buildCareerStatsMatrix(),

            const SizedBox(height: 16),

            // 4. VIP Club Privileges & Level Journey
            _buildVipPrivilegesCard(),

            const SizedBox(height: 16),

            // 5. Interactive Arcade Audio & Haptic Console
            _buildAudioHapticsConsole(),

            const SizedBox(height: 16),

            // 6. Achievements (derived from real career stats)
            _buildAchievementsCard(),

            const SizedBox(height: 22),

            // 7. Engine Security & Version Badge
            _buildEngineFooter(),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 1. DOSSIER HEADER
  // ---------------------------------------------------------------------------
  Widget _buildDossierHeader() {
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
              Icons.military_tech_rounded,
              color: Color(0xFF1B0733),
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'COMMANDER DOSSIER',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.shield_rounded, color: AppColors.gold, size: 14),
                  ],
                ),
                SizedBox(height: 2),
                Text(
                  'Milky Way VIP License & Account Console',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textDim,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Callsign chip with copy action
          GestureDetector(
            onTap: _copyCallsign,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.teal.withValues(alpha: 0.5),
                  width: 0.8,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.badge_rounded, color: AppColors.teal, size: 12),
                  SizedBox(width: 4),
                  Text(
                    '#MW-7749',
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
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. HOLOGRAPHIC VIP PASSPORT CARD
  // ---------------------------------------------------------------------------
  Widget _buildHoloPassportCard() {
    final progress = wallet.levelProgress.clamp(0.02, 1.0);
    final currentLvlXp = wallet.xp % WalletService.xpPerLevel;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF3B1568),
            Color(0xFF1E083B),
            Color(0xFF120326),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.gold, width: 1.6),
        boxShadow: [
          const BoxShadow(
            color: Color(0xFF070014),
            offset: Offset(0, 5),
            blurRadius: 0,
          ),
          BoxShadow(
            color: AppColors.purple.withValues(alpha: 0.35),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar + Info Row
              Row(
                children: [
                  // Avatar with level badge
                  Stack(
                    alignment: Alignment.bottomCenter,
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 74,
                        height: 74,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.gold.withValues(alpha: 0.15),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.gold.withValues(alpha: 0.3),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/avatar/avatar_frame.png',
                          width: 72,
                          height: 72,
                        ),
                      ),
                      Positioned(
                        bottom: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 1.5),
                          decoration: BoxDecoration(
                            gradient: AppColors.goldGradient,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF261002),
                              width: 1.2,
                            ),
                          ),
                          child: Text(
                            'Lv ${wallet.level}',
                            style: const TextStyle(
                              color: Color(0xFF261002),
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(width: 16),

                  // Commander Title & VIP Rank
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Cosmic Commander',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.verified_rounded,
                                color: AppColors.teal, size: 16),
                          ],
                        ),
                        const SizedBox(height: 5),

                        // VIP Tier Chip
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: _vipTierColor.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _vipTierColor.withValues(alpha: 0.8),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            _vipTierTitle,
                            style: TextStyle(
                              color: _vipTierColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 9.5,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),

                        const SizedBox(height: 5),

                        Text(
                          wallet.vipPointsToNext > 0
                              ? '${wallet.vipPointsToNext} VIP pts to next tier'
                              : 'Top VIP tier reached!',
                          style: const TextStyle(
                            color: AppColors.gold,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Level Progression Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'LEVEL PROGRESSION',
                    style: TextStyle(
                      color: AppColors.textDim,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: const TextStyle(
                      color: AppColors.teal,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 9,
                  backgroundColor: const Color(0xFF0C031E),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.teal),
                ),
              ),

              const SizedBox(height: 5),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$currentLvlXp / ${WalletService.xpPerLevel} XP',
                    style: const TextStyle(
                      color: AppColors.textDim,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Level ${wallet.level + 1} unlocks next',
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. CAREER STATISTICS MATRIX (HALL OF FAME)
  // ---------------------------------------------------------------------------
  Widget _buildCareerStatsMatrix() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.workspace_premium_rounded,
                color: AppColors.gold, size: 18),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'CAREER TROPHY MATRIX',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13.5,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Real career stats (persisted), not a re-print of the top balance bar.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _statTile(
                  label: 'BIGGEST WIN',
                  value: CurrencyBar.format(wallet.biggestWin),
                  asset: 'assets/images/currency/coin.png',
                  color: AppColors.gold,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statTile(
                  label: 'TOTAL WON',
                  value: CurrencyBar.format(wallet.totalWon),
                  icon: Icons.trending_up_rounded,
                  color: const Color(0xFF69F0AE),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _statTile(
                  label: 'TOTAL SPINS',
                  value: CurrencyBar.format(wallet.totalSpins),
                  icon: Icons.casino_rounded,
                  color: AppColors.teal,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statTile(
                  label: 'GAMES PLAYED',
                  value: CurrencyBar.format(wallet.gamesPlayed),
                  icon: Icons.sports_esports_rounded,
                  color: AppColors.magenta,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _statTile(
                  label: 'SLOT REALMS',
                  value: '$_unlockedGames / ${kGames.length} UNLOCKED',
                  icon: Icons.lock_open_rounded,
                  color: const Color(0xFF7C4DFF),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statTile(
                  label: 'DAILY STREAK',
                  value: 'DAY ${eng.currentStreakDay} / 7',
                  icon: Icons.local_fire_department_rounded,
                  color: const Color(0xFFFF9100),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  int get _unlockedGames =>
      kGames.where((g) => g.unlockedAt(wallet.level)).length;

  Widget _statTile({
    required String label,
    required String value,
    String? asset,
    IconData? icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C0A38),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF070014),
            offset: Offset(0, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              if (asset != null)
                Image.asset(asset, width: 16, height: 16)
              else if (icon != null)
                Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textDim,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. VIP CLUB PRIVILEGES
  // ---------------------------------------------------------------------------
  Widget _buildVipPrivilegesCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2A0D52),
            Color(0xFF13042A),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.6),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF070014),
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
              const Icon(Icons.stars_rounded, color: AppColors.gold, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'VIP CLUB STATUS & PERKS',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'TIER ${wallet.vipTierIndex + 1}',
                  style: const TextStyle(
                    color: AppColors.teal,
                    fontWeight: FontWeight.w900,
                    fontSize: 9.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Real VIP ladder progress (earned by total coins wagered).
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                wallet.vipTier.name,
                style: TextStyle(
                  color: _vipTierColor,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                wallet.vipPointsToNext > 0
                    ? '${wallet.vipPointsToNext} pts to next'
                    : 'MAX TIER',
                style: const TextStyle(
                  color: AppColors.textDim,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: wallet.vipProgress,
              minHeight: 7,
              backgroundColor: const Color(0xFF100525),
              valueColor: AlwaysStoppedAnimation<Color>(_vipTierColor),
            ),
          ),
          const SizedBox(height: 10),
          _perkRow(Icons.check_circle_rounded,
              'Earn 1 VIP point per ${CurrencyBar.format(WalletService.vipPointPerWager)} coins wagered'),
          const SizedBox(height: 4),
          _perkRow(Icons.check_circle_rounded,
              'Level-up reward crates delivered to your Mailbox'),
          const SizedBox(height: 4),
          _perkRow(Icons.check_circle_rounded,
              'Daily missions & streak keep your vault growing'),
        ],
      ),
    );
  }

  Widget _perkRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppColors.teal, size: 14),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 5. INTERACTIVE ARCADE AUDIO & HAPTIC CONSOLE
  // ---------------------------------------------------------------------------
  Widget _buildAudioHapticsConsole() {
    return ListenableBuilder(
      listenable: sound,
      builder: (context, _) {
        final anyOn = sound.musicEnabled || sound.sfxEnabled || sound.hapticsEnabled;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A0A38),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.45),
              width: 1.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0xFF070014),
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
                  const Icon(Icons.volume_up_rounded,
                      color: AppColors.gold, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'AUDIO & HAPTIC CONSOLE',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: anyOn
                          ? const Color(0xFF00E676).withValues(alpha: 0.2)
                          : Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      anyOn ? 'ACTIVE' : 'MUTED',
                      style: TextStyle(
                        color: anyOn
                            ? const Color(0xFF00E676)
                            : const Color(0xFFFF5252),
                        fontWeight: FontWeight.w900,
                        fontSize: 9.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _settingSwitch(
                icon: Icons.music_note_rounded,
                title: 'Background Music',
                subtitle: 'Looping lobby & in-game soundtrack',
                value: sound.musicEnabled,
                onChanged: sound.setMusicEnabled,
              ),
              _settingSwitch(
                icon: Icons.graphic_eq_rounded,
                title: 'Sound Effects',
                subtitle: 'Spins, wins, coins and taps',
                value: sound.sfxEnabled,
                onChanged: (v) {
                  sound.setSfxEnabled(v);
                  if (v) sound.win();
                },
              ),
              _settingSwitch(
                icon: Icons.vibration_rounded,
                title: 'Haptic Vibration',
                subtitle: 'Tactile pulses on spins and wins',
                value: sound.hapticsEnabled,
                onChanged: (v) {
                  sound.setHapticsEnabled(v);
                  if (v) sound.hapticMedium();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _settingSwitch({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon,
              color: value ? AppColors.gold : Colors.white38, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textDim,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AppColors.gold,
            activeTrackColor: const Color(0xFF381B68),
            inactiveThumbColor: Colors.grey.shade600,
            inactiveTrackColor: Colors.black38,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 6. ACHIEVEMENTS (derived from persisted career stats)
  // ---------------------------------------------------------------------------
  List<_Achievement> get _achievements => [
        _Achievement('First Spin', Icons.play_arrow_rounded,
            wallet.totalSpins >= 1),
        _Achievement('Century Spinner · 100 spins', Icons.autorenew_rounded,
            wallet.totalSpins >= 100),
        _Achievement('Big Winner · win 10K in one spin',
            Icons.local_fire_department_rounded, wallet.biggestWin >= 10000),
        _Achievement('Millionaire · 1M total won',
            Icons.workspace_premium_rounded, wallet.totalWon >= 1000000),
        _Achievement('High Roller · 500K wagered', Icons.diamond_rounded,
            wallet.totalWagered >= 500000),
        _Achievement('Galaxy Explorer · unlock all realms',
            Icons.lock_open_rounded, _unlockedGames >= kGames.length),
        _Achievement('Week Warrior · 7-day streak',
            Icons.calendar_month_rounded, eng.currentStreakDay >= 7),
      ];

  Widget _buildAchievementsCard() {
    final items = _achievements;
    final earned = items.where((a) => a.done).length;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF14052B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.45),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF070014),
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
              const Icon(Icons.emoji_events_rounded,
                  color: AppColors.gold, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'ACHIEVEMENTS',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$earned / ${items.length}',
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w900,
                    fontSize: 9.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final a in items) ...[
            Row(
              children: [
                Icon(
                  a.done ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
                  color: a.done ? const Color(0xFF69F0AE) : AppColors.textDim,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    a.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: a.done ? Colors.white : AppColors.textDim,
                      fontSize: 11.5,
                      fontWeight: a.done ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                Icon(a.icon,
                    color: a.done ? AppColors.gold : Colors.white24, size: 15),
              ],
            ),
            const SizedBox(height: 7),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 7. ENGINE FOOTER
  // ---------------------------------------------------------------------------
  Widget _buildEngineFooter() {
    return Center(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.teal,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'MILKY WAY ARCADE ENGINE · v1.0.0',
                style: TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          const Text(
            'High-Performance 2.5D Slot Simulator • All Local State Secured',
            style: TextStyle(
              color: AppColors.textDim,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

/// A derived achievement: a title + icon + whether career stats satisfy it.
class _Achievement {
  final String title;
  final IconData icon;
  final bool done;
  const _Achievement(this.title, this.icon, this.done);
}
