import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../engine/slot_engine.dart';
import '../engine/slot_symbol.dart';
import '../services/engagement_service.dart';
import '../services/real_play_service.dart';
import '../services/sound_service.dart';
import '../services/wallet_service.dart';
import '../theme/app_theme.dart';
import '../widgets/coin_fly_overlay.dart';
import '../widgets/cosmic_button.dart';
import '../widgets/currency_bar.dart';
import '../widgets/win_celebration.dart';

/// Deluxe Vegas Arcade Slot Machine.
/// Features:
/// - Snug, authentic Vegas cabinet wrapping large 5x3 reels with 3D cylindrical drum glass
/// - Multi-tier progressive jackpot ticker marquee
/// - Glowing LED matrix win/status marquee
/// - Two-tier ergonomic arcade console deck (Utility row + Bet Stepper & Hero Spin dome)
/// - Zero overflows, zero dead empty voids, 100% responsive
/// - Interactive Paytable modal & Slam-Stop support
class SlotMachine extends StatefulWidget {
  final String title;
  final SlotConfig config;
  final WalletService wallet;
  final EngagementService? engagement;
  final String background;
  final bool cascades;
  final bool expandingWild;
  final int stickyWildSpins;

  const SlotMachine({
    super.key,
    required this.title,
    required this.config,
    required this.wallet,
    this.engagement,
    this.background = 'assets/images/lobby/lobby_background.png',
    this.cascades = false,
    this.expandingWild = false,
    this.stickyWildSpins = 0,
  });

  @override
  State<SlotMachine> createState() => _SlotMachineState();
}

class _SlotMachineState extends State<SlotMachine> {
  static const _ladder = [1, 2, 3, 5];
  late final SlotEngine _engine;

  late List<List<SlotSymbol>> _display;
  List<bool> _reelSpinning = [];
  Set<int> _winCells = {};
  final Map<int, int> _sticky = {};
  bool _spinning = false;
  int _betIndex = 0;
  int _freeSpins = 0;
  int _lastSpinBet = 0; // wager for the in-flight spin (0 on a free spin)
  int _lastWin = 0;
  int _cascadeMult = 1;
  Timer? _shuffle;
  final List<Timer> _reelTimers = [];
  List<List<SlotSymbol>>? _targetGrid;

  bool _turbo = false;
  int _autoSpinsRemaining = 0;
  Timer? _jackpotTimer;
  int _jackpotTick = 0;
  bool _spinPressed = false;

  SlotConfig get c => widget.config;
  // Total-bet levels (multiples of 50) scale with the player's balance.
  List<int> get _betLevels => betLevelsForBalance(widget.wallet.coins);
  int get _betIndexClamped => _betIndex.clamp(0, _betLevels.length - 1);
  int get _totalBet => _betLevels[_betIndexClamped];
  int get _betPerLine => _totalBet ~/ c.betMultiplier();
  bool get _isMaxBet => _betIndexClamped == _betLevels.length - 1;

  @override
  void initState() {
    super.initState();
    _engine = SlotEngine(c);
    _display = _engine.randomGrid();
    _reelSpinning = List.filled(c.reels, false);

    _jackpotTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        setState(() => _jackpotTick = (_jackpotTick + 19) % 10000);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final size = MediaQuery.sizeOf(context);
        final top = MediaQuery.paddingOf(context).top;
        CoinFlyService.setCoinTarget(Offset(size.width - 55, top + 24));
      }
    });
  }

  @override
  void dispose() {
    CoinFlyService.setCoinTarget(null);
    _shuffle?.cancel();
    _cancelReelTimers();
    _jackpotTimer?.cancel();
    super.dispose();
  }

  void _cancelReelTimers() {
    for (final t in _reelTimers) {
      t.cancel();
    }
    _reelTimers.clear();
  }

  void _changeBet(int dir) {
    if (_spinning || _freeSpins > 0) return;
    sound.tap();
    setState(() =>
        _betIndex = (_betIndexClamped + dir).clamp(0, _betLevels.length - 1));
  }

  void _maxBet() {
    if (_spinning || _freeSpins > 0 || _isMaxBet) return;
    sound.tap();
    sound.hapticHeavy();
    setState(() => _betIndex = _betLevels.length - 1);
  }

  void _toggleTurbo() {
    sound.tap();
    setState(() => _turbo = !_turbo);
  }

  void _cycleAutoSpin() {
    sound.tap();
    setState(() {
      if (_autoSpinsRemaining == 0) {
        _autoSpinsRemaining = 10;
      } else if (_autoSpinsRemaining == 10) {
        _autoSpinsRemaining = 25;
      } else if (_autoSpinsRemaining == 25) {
        _autoSpinsRemaining = 50;
      } else {
        _autoSpinsRemaining = 0;
      }
    });

    if (_autoSpinsRemaining > 0 && !_spinning) {
      _spin();
    }
  }

  void _cancelAutoSpin() {
    if (_autoSpinsRemaining > 0) {
      setState(() => _autoSpinsRemaining = 0);
    }
  }

  void _slamStop() {
    if (!_spinning || _targetGrid == null) return;
    _cancelReelTimers();
    _shuffle?.cancel();

    setState(() {
      _display = _targetGrid!;
      _reelSpinning = List.filled(c.reels, false);
    });

    sound.reelStop();
    _afterStop(_targetGrid!);
  }

  void _spin() {
    if (_spinning) {
      _slamStop();
      return;
    }

    final free = _freeSpins > 0;
    if (!free) {
      if (!widget.wallet.spendCoins(_totalBet)) {
        _cancelAutoSpin();
        _handleCantAfford();
        return;
      }
    } else {
      setState(() => _freeSpins--);
    }
    _lastSpinBet = free ? 0 : _totalBet;

    final grid = _engine.randomGrid();
    if (widget.stickyWildSpins > 0) _applySticky(grid);
    _targetGrid = grid;

    sound.spinStart();
    _cancelReelTimers();

    setState(() {
      _spinning = true;
      _lastWin = 0;
      _cascadeMult = 1;
      _winCells = {};
      _reelSpinning = List.filled(c.reels, true);
    });

    _shuffle = Timer.periodic(const Duration(milliseconds: 55), (_) {
      if (!mounted) return;
      setState(() {
        for (var r = 0; r < c.reels; r++) {
          if (_reelSpinning[r]) {
            _display[r] = List.generate(c.rows, (_) => _engine.pick());
          }
        }
      });
    });

    final baseDelay = _turbo ? 180 : 450;
    final stepDelay = _turbo ? 90 : 200;

    for (var r = 0; r < c.reels; r++) {
      final t = Timer(Duration(milliseconds: baseDelay + r * stepDelay), () {
        if (!mounted || !_spinning) return;
        setState(() {
          _display[r] = grid[r];
          _reelSpinning[r] = false;
        });
        sound.reelStop();
        if (r == c.reels - 1) _afterStop(grid);
      });
      _reelTimers.add(t);
    }
  }

  Future<void> _afterStop(List<List<SlotSymbol>> grid) async {
    _shuffle?.cancel();
    _cancelReelTimers();
    sound.spinStop();

    if (widget.cascades) {
      await _runCascades();
    } else if (widget.expandingWild) {
      await _runExpanding();
    } else {
      _settleOnce();
    }
    if (widget.stickyWildSpins > 0) _ageSticky();
    _finishSpin();
  }

  void _settleOnce() {
    final e = _engine.evaluateGrid(_display, _betPerLine);
    var win = e.lineTotal;
    if (widget.stickyWildSpins > 0) {
      final m = _stickyMultiplier();
      win *= m;
      _cascadeMult = m;
    }
    _award(e.winCells, win, e);
  }

  Future<void> _runCascades() async {
    var step = 0;
    var totalWin = 0;
    Set<int> lastCells = {};
    while (true) {
      final e = _engine.evaluateGrid(_display, _betPerLine);
      if (e.wins.isEmpty) {
        if (step == 0 && e.scatterPay > 0) totalWin += e.scatterPay;
        break;
      }
      final mult = _ladder[min(step, _ladder.length - 1)];
      totalWin += e.lineTotal * mult;
      lastCells = e.winCells;
      setState(() {
        _winCells = e.winCells;
        _cascadeMult = mult;
        _lastWin = totalWin;
      });
      await Future.delayed(Duration(milliseconds: _turbo ? 280 : 500));
      _collapse(e.winCells);
      setState(() {});
      await Future.delayed(Duration(milliseconds: _turbo ? 120 : 220));
      step++;
    }
    setState(() {
      _winCells = lastCells;
      _lastWin = totalWin;
    });
    if (totalWin > 0) {
      widget.wallet.addCoins(totalWin, origin: _getReelOrigin());
    }
    _maybeAwardFreeSpins(_engine.evaluateGrid(_display, _betPerLine));
  }

  void _collapse(Set<int> winCells) {
    for (var reel = 0; reel < c.reels; reel++) {
      final survivors = <SlotSymbol>[];
      for (var row = 0; row < c.rows; row++) {
        if (!winCells.contains(reel * c.rows + row)) {
          survivors.add(_display[reel][row]);
        }
      }
      final needed = c.rows - survivors.length;
      _display[reel] = [
        for (var i = 0; i < needed; i++) _engine.pick(),
        ...survivors,
      ];
    }
  }

  Future<void> _runExpanding() async {
    var totalWin = 0;
    var respins = 0;
    const maxRespins = 3;
    while (true) {
      var expanded = false;
      for (var reel = 1; reel < c.reels - 1; reel++) {
        if (_display[reel].any((s) => s.isWild)) {
          _display[reel] = List.filled(c.rows, c.wild);
          expanded = true;
        }
      }
      if (expanded) setState(() {});
      final e = _engine.evaluateGrid(_display, _betPerLine);
      totalWin += e.lineTotal;
      setState(() {
        _winCells = e.winCells;
        _lastWin = totalWin;
      });
      _maybeAwardFreeSpins(e);
      if (expanded && respins < maxRespins && e.wins.isNotEmpty) {
        respins++;
        await Future.delayed(Duration(milliseconds: _turbo ? 300 : 550));
        _respinNonWildReels();
        await Future.delayed(Duration(milliseconds: _turbo ? 120 : 180));
        continue;
      }
      break;
    }
    if (totalWin > 0) {
      widget.wallet.addCoins(totalWin, origin: _getReelOrigin());
    }
  }

  Offset _getReelOrigin() {
    final size = MediaQuery.sizeOf(context);
    return Offset(size.width * 0.5, size.height * 0.38);
  }

  void _respinNonWildReels() {
    for (var reel = 0; reel < c.reels; reel++) {
      final allWild = _display[reel].every((s) => s.isWild);
      if (!allWild) _display[reel] = List.generate(c.rows, (_) => _engine.pick());
    }
    setState(() {});
  }

  void _applySticky(List<List<SlotSymbol>> grid) {
    for (final cell in _sticky.keys) {
      grid[cell ~/ c.rows][cell % c.rows] = c.wild;
    }
    for (var reel = 0; reel < c.reels; reel++) {
      for (var row = 0; row < c.rows; row++) {
        if (grid[reel][row].isWild) {
          _sticky[reel * c.rows + row] = widget.stickyWildSpins;
        }
      }
    }
  }

  int _stickyMultiplier() =>
      _sticky.isEmpty ? 1 : min(1 + _sticky.length, 10);

  void _ageSticky() {
    if (_freeSpins > 0) return;
    final expired = <int>[];
    _sticky.updateAll((_, v) => v - 1);
    _sticky.forEach((k, v) {
      if (v <= 0) expired.add(k);
    });
    for (final k in expired) {
      _sticky.remove(k);
    }
  }

  void _award(Set<int> cells, int win, GridEval e) {
    setState(() {
      _winCells = cells;
      _lastWin = win;
    });
    if (win > 0) {
      widget.wallet.addCoins(win, origin: _getReelOrigin());
    }
    _maybeAwardFreeSpins(e);
  }

  void _maybeAwardFreeSpins(GridEval e) {
    if (e.scatterCount >= c.freeSpinScatters) {
      setState(() => _freeSpins += c.freeSpinCount);
      _banner('🌌 ${c.freeSpinCount} FREE SPINS!');
    }
  }

  void _finishSpin() {
    setState(() => _spinning = false);
    final tier = winTierFor(_lastWin, _totalBet);

    // Record the completed spin: career stats, bet-scaled XP, daily missions.
    widget.wallet.recordSpin(bet: _lastSpinBet, win: _lastWin);
    widget.engagement?.recordSpins(1);
    if (_lastWin > 0) widget.engagement?.recordWinCoins(_lastWin);
    if (tier != WinTier.none) widget.engagement?.recordBigWin();

    if (tier != WinTier.none) {
      sound.bigWin();
      showWinCelebration(context, _lastWin, tier);
    } else if (_lastWin > 0) {
      sound.win();
    }

    if (_autoSpinsRemaining > 0 && mounted) {
      setState(() => _autoSpinsRemaining--);
      if (_autoSpinsRemaining > 0) {
        Future.delayed(Duration(milliseconds: _turbo ? 350 : 650), () {
          if (mounted && _autoSpinsRemaining > 0 && !_spinning) {
            _spin();
          }
        });
      }
    }
  }

  void _handleCantAfford() {
    if (widget.wallet.isBroke) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.deepPurple,
          title: const Text('Out of Coins!',
              style: TextStyle(color: AppColors.gold)),
          content: Text(
              'Collect ${WalletService.rescueAmount} coins to keep playing.',
              style: const TextStyle(color: Colors.white)),
          actions: [
            CosmicButton(
              label: 'Collect Free',
              onTap: () {
                widget.wallet.grantRescue();
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 8),
            CosmicButton(
              label: 'PLAY REAL CASH ↗',
              icon: Icons.open_in_new_rounded,
              gradient: const LinearGradient(
                colors: [Color(0xFFFFB300), Color(0xFFFF6F00)],
              ),
              onTap: () {
                RealPlayService.openRealPlay();
                widget.wallet.grantRescue();
                Navigator.pop(context);
              },
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough coins — lower your bet')),
      );
    }
  }

  void _banner(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.purple,
      duration: const Duration(seconds: 2),
      content: Text(text,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white)),
    ));
  }

  // ---------------------------------------------------------------------------
  // MAIN BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070014),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Cosmic Atmosphere
          Image.asset(widget.background,
              fit: BoxFit.cover),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF0B041C).withValues(alpha: 0.85),
                  const Color(0xFF13042E).withValues(alpha: 0.45),
                  const Color(0xFF060012).withValues(alpha: 0.95),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // 1. Arcade Header Bar
                _buildArcadeHeader(),

                const SizedBox(height: 4),

                // 2. Progressive Jackpot Marquee
                _buildJackpotMarquee(),

                const Spacer(flex: 1),

                // 3. Physical Vegas Slot Cabinet (Snugly wrapping the reels, ZERO empty void)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: RepaintBoundary(child: _buildCabinetReels()),
                ),

                const Spacer(flex: 1),

                // 4. LED Dot-Matrix Digital Status Marquee
                _buildStatusMarquee(),

                const SizedBox(height: 6),

                // 5. Two-Tier Ergonomic Arcade Console Deck (Never overflows)
                _buildConsoleDeck(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. ARCADE HEADER BAR (Clean, un-truncated, well-spaced)
  // ---------------------------------------------------------------------------
  Widget _buildArcadeHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
      child: Row(
        children: [
          // Back Button
          _arcadeRoundBtn(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.pop(context),
            tooltip: 'Lobby',
          ),

          const SizedBox(width: 8),

          // Title & Payline Badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    shadows: [
                      Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1.5)),
                    ],
                  ),
                ),
                Text(
                  c.mode == WinMode.ways ? '243 WAYS • BOTH WAYS' : '${c.paylines.length} PAYLINES ACTIVE',
                  style: const TextStyle(
                    color: AppColors.teal,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),

          // Paytable / Rules Button
          _arcadeRoundBtn(
            icon: Icons.info_outline_rounded,
            onTap: _showPaytable,
            tooltip: 'Paytable',
            iconColor: AppColors.teal,
          ),

          const SizedBox(width: 6),

          // Real Play Header Action
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              sound.win();
              RealPlayService.openRealPlay();
            },
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFB300), Color(0xFFFF6F00)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66FF8F00),
                    blurRadius: 6,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.monetization_on_rounded,
                    color: Color(0xFF2E1200),
                    size: 14,
                  ),
                  SizedBox(width: 3),
                  Text(
                    'REAL',
                    style: TextStyle(
                      color: Color(0xFF2E1200),
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 6),

          // Sound Toggle Button
          ListenableBuilder(
            listenable: sound,
            builder: (context, _) => _arcadeRoundBtn(
              icon: sound.anyAudioOn
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
              onTap: () {
                final on = !sound.anyAudioOn;
                sound.setAllAudio(on);
                if (on) sound.tap();
              },
              tooltip: 'Sound',
              iconColor: sound.anyAudioOn ? AppColors.gold : Colors.white38,
            ),
          ),

          const SizedBox(width: 8),

          // Player Wallet Balance Pill
          ListenableBuilder(
            listenable: widget.wallet,
            builder: (context, _) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
              decoration: BoxDecoration(
                color: const Color(0xFF170932),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.7),
                  width: 1.2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0xFF080112),
                    offset: Offset(0, 2),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/currency/coin.png',
                    width: 17,
                    height: 17,
                    cacheWidth: 60,
                  ),
                  const SizedBox(width: 5),
                  RollingNumberText(
                    value: widget.wallet.coins,
                    gainType: CurrencyGainType.coin,
                    formatter: CurrencyBar.format,
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 0.3,
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

  Widget _arcadeRoundBtn({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
    Color iconColor = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFF1D093B),
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.gold.withValues(alpha: 0.45),
            width: 1.2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0xFF0A0216),
              offset: Offset(0, 2),
              blurRadius: 0,
            ),
          ],
        ),
        child: Icon(icon, size: 15, color: iconColor),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. PROGRESSIVE JACKPOT MARQUEE
  // ---------------------------------------------------------------------------
  Widget _buildJackpotMarquee() {
    final base = _betPerLine;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF280B4E), Color(0xFF14022A)],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.gold.withValues(alpha: 0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.15),
              blurRadius: 6,
            ),
          ],
        ),
        child: Row(
          children: [
            _jackpotBadge('MINI', base * 400 + (_jackpotTick % 50), const Color(0xFFE040FB)),
            const SizedBox(width: 4),
            _jackpotBadge('MINOR', base * 2000 + (_jackpotTick * 2 % 200), const Color(0xFF00E676)),
            const SizedBox(width: 4),
            _jackpotBadge('MAJOR', base * 10000 + (_jackpotTick * 5 % 1000), AppColors.teal),
            const SizedBox(width: 4),
            _jackpotBadge('GRAND', base * 50000 + (_jackpotTick * 10), AppColors.gold, isGrand: true),
          ],
        ),
      ),
    );
  }

  Widget _jackpotBadge(String name, int amount, Color accent, {bool isGrand = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: accent.withValues(alpha: isGrand ? 0.9 : 0.4),
            width: isGrand ? 1.2 : 0.8,
          ),
          boxShadow: isGrand
              ? [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.35),
                    blurRadius: 6,
                  )
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w900,
                fontSize: 8.5,
                letterSpacing: 0.6,
              ),
            ),
            Text(
              CurrencyBar.format(amount),
              maxLines: 1,
              style: TextStyle(
                color: isGrand ? const Color(0xFFFFF2A8) : Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 10,
                letterSpacing: 0.2,
                shadows: isGrand
                    ? const [Shadow(color: AppColors.gold, blurRadius: 4)]
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. PHYSICAL VEGAS SLOT CABINET (Snug fit to reels, NO empty voids!)
  // ---------------------------------------------------------------------------
  Widget _buildCabinetReels() {
    // The entire cabinet aspect ratio locks snugly to the reels + bezel
    return AspectRatio(
      aspectRatio: 1.55,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF120329),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.gold,
            width: 3.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.4),
              blurRadius: 18,
              spreadRadius: 1,
            ),
            const BoxShadow(
              color: Color(0xFF050010),
              offset: Offset(0, 5),
              blurRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Inner Cabinet Background Grid
              Row(
                children: [
                  // Left Payline Rail
                  _paylineRail(isLeft: true),

                  // Slot Reels Grid
                  Expanded(
                    child: Container(
                      color: const Color(0xFF090214),
                      child: Row(
                        children: [
                          for (var reel = 0; reel < c.reels; reel++) ...[
                            if (reel > 0)
                              // Chrome reel column lightbar divider
                              Container(
                                width: 1.5,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      AppColors.gold.withValues(alpha: 0.6),
                                      Colors.white.withValues(alpha: 0.8),
                                      AppColors.gold.withValues(alpha: 0.6),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            Expanded(
                              child: Column(
                                children: [
                                  for (var row = 0; row < c.rows; row++)
                                    Expanded(child: _cell(reel, row)),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Right Payline Rail
                  _paylineRail(isLeft: false),
                ],
              ),

              // 3D Cylindrical Drum Glass Overlay (Top & Bottom Curve Shadows)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.16, 0.84, 1.0],
                        colors: [
                          Colors.black.withValues(alpha: 0.65),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.65),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Specular Glass Sheen Highlight Arc
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        stops: const [0.0, 0.35, 0.45, 1.0],
                        colors: [
                          Colors.white.withValues(alpha: 0.08),
                          Colors.white.withValues(alpha: 0.02),
                          Colors.transparent,
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 4 Corner Gold Rivets / Cyber Brackets
              _cornerBolt(top: 4, left: 4),
              _cornerBolt(top: 4, right: 4),
              _cornerBolt(bottom: 4, left: 4),
              _cornerBolt(bottom: 4, right: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _paylineRail({required bool isLeft}) {
    final colors = [
      AppColors.gold,
      AppColors.teal,
      const Color(0xFFE040FB),
    ];
    return Container(
      width: 13,
      color: const Color(0xFF14052B),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              width: 6,
              height: 14,
              decoration: BoxDecoration(
                color: colors[i % colors.length],
                borderRadius: BorderRadius.circular(3),
                boxShadow: [
                  BoxShadow(
                    color: colors[i % colors.length].withValues(alpha: 0.6),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _cornerBolt({double? top, double? bottom, double? left, double? right}) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.goldGradient,
          border: Border.all(color: const Color(0xFF2B1002), width: 1),
          boxShadow: const [
            BoxShadow(color: Colors.black87, blurRadius: 2),
          ],
        ),
      ),
    );
  }

  Widget _cell(int reel, int row) {
    final sym = _display[reel][row];
    final win = _winCells.contains(reel * c.rows + row) && !_spinning;
    final isSticky = _sticky.containsKey(reel * c.rows + row);

    return PulseGlow(
      active: win,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 2.5),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              win
                  ? AppColors.gold.withValues(alpha: 0.45)
                  : sym.color.withValues(alpha: 0.18),
              win
                  ? const Color(0xFF632B00).withValues(alpha: 0.65)
                  : const Color(0xFF120328).withValues(alpha: 0.70),
            ],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: win
                ? AppColors.gold
                : Colors.white.withValues(alpha: 0.10),
            width: win ? 2.4 : 1,
          ),
          boxShadow: win
              ? [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.8),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(4.5),
              child: sym.asset != null
                  ? Image.asset(sym.asset!, fit: BoxFit.contain, cacheWidth: 200)
                  : Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          sym.glyph,
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: sym.pays.isEmpty || sym.glyph.length > 1
                                ? Colors.white
                                : sym.color,
                            shadows: const [
                              Shadow(color: Colors.black87, blurRadius: 4),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),

            if (isSticky)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.gold, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_rounded, color: AppColors.gold, size: 9),
                      const SizedBox(width: 2),
                      Text(
                        '${_sticky[reel * c.rows + row]}',
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. LED MATRIX DIGITAL STATUS MARQUEE
  // ---------------------------------------------------------------------------
  Widget _buildStatusMarquee() {
    final showWin = _lastWin > 0 && !_spinning;
    final showMult = _cascadeMult > 1;

    String text;
    Color color;
    IconData icon;

    if (_freeSpins > 0) {
      text = '🔥 FREE SPINS ACTIVE: $_freeSpins REMAINING 🔥';
      color = AppColors.teal;
      icon = Icons.local_fire_department_rounded;
    } else if (showWin) {
      text = '★ BIG WIN! +${CurrencyBar.format(_lastWin)} COINS! ${showMult ? '• x$_cascadeMult BOOST' : ''} ★';
      color = AppColors.gold;
      icon = Icons.celebration_rounded;
    } else if (_spinning) {
      text = '⚡ REELS IN MOTION... MAY FORTUNE FAVOR YOU ⚡';
      color = const Color(0xFFFFF2A8);
      icon = Icons.bolt_rounded;
    } else {
      text = '✨ 25 PAYLINES ACTIVE • TAP SPIN TO WIN ✨';
      color = AppColors.textDim;
      icon = Icons.stars_rounded;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF130429),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: showWin
                ? AppColors.gold
                : AppColors.gold.withValues(alpha: 0.35),
            width: showWin ? 1.4 : 1,
          ),
          boxShadow: showWin
              ? [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.4),
                    blurRadius: 10,
                  )
                ]
              : const [
                  BoxShadow(
                    color: Color(0xFF060010),
                    offset: Offset(0, 2),
                    blurRadius: 0,
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 8),
            Flexible(
              child: showWin
                  ? CountUpText(
                      key: ValueKey(_lastWin),
                      amount: _lastWin,
                      prefix: 'WIN  +',
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w900,
                        fontSize: 14.5,
                        letterSpacing: 0.5,
                      ),
                    )
                  : Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 0.3,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 5. TWO-TIER ERGONOMIC ARCADE CONSOLE DECK (ZERO OVERFLOW!)
  // ---------------------------------------------------------------------------
  Widget _buildConsoleDeck() {
    final locked = _spinning || _freeSpins > 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF220B4A),
            Color(0xFF100326),
          ],
        ),
        border: Border(
          top: BorderSide(
            color: AppColors.gold.withValues(alpha: 0.7),
            width: 1.5,
          ),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF04000C),
            offset: Offset(0, -5),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Quick Action Utility Buttons (Turbo, Auto, Max Bet)
          Row(
            children: [
              // Turbo Button
              Expanded(
                child: _utilityPillBtn(
                  label: 'TURBO',
                  icon: Icons.bolt_rounded,
                  active: _turbo,
                  onTap: _toggleTurbo,
                  activeColor: AppColors.teal,
                ),
              ),
              const SizedBox(width: 6),

              // Auto-Spin Button
              Expanded(
                child: _utilityPillBtn(
                  label: _autoSpinsRemaining > 0 ? 'AUTO ($_autoSpinsRemaining)' : 'AUTO SPIN',
                  icon: Icons.sync_rounded,
                  active: _autoSpinsRemaining > 0,
                  onTap: locked ? _cancelAutoSpin : _cycleAutoSpin,
                  activeColor: const Color(0xFFE040FB),
                ),
              ),
              const SizedBox(width: 6),

              // Max Bet Button
              Expanded(
                child: _utilityPillBtn(
                  label: 'MAX BET',
                  icon: Icons.workspace_premium_rounded,
                  active: _isMaxBet,
                  onTap: locked || _isMaxBet ? null : _maxBet,
                  activeColor: AppColors.gold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Row 2: Main Action Row (Bet Stepper + Giant Spin Button)
          Row(
            children: [
              // Total Bet Stepper Console
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF15042E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.45),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'TOTAL BET',
                      style: TextStyle(
                        color: AppColors.textDim,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _stepCircleBtn(
                          icon: Icons.remove,
                          onTap: locked ? null : () => _changeBet(-1),
                        ),
                        SizedBox(
                          width: 52,
                          child: Text(
                            CurrencyBar.format(_totalBet),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.gold,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        _stepCircleBtn(
                          icon: Icons.add,
                          onTap: locked ? null : () => _changeBet(1),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Hero 3D Arcade SPIN Button
              Expanded(child: _buildHeroSpinButton()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _utilityPillBtn({
    required String label,
    required IconData icon,
    required bool active,
    VoidCallback? onTap,
    required Color activeColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 28,
        decoration: BoxDecoration(
          color: active
              ? activeColor.withValues(alpha: 0.25)
              : const Color(0xFF15042E),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: active ? activeColor : AppColors.gold.withValues(alpha: 0.35),
            width: active ? 1.4 : 0.8,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 13,
              color: active ? activeColor : Colors.white60,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: active ? activeColor : Colors.white70,
                fontWeight: FontWeight.w900,
                fontSize: 9.5,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepCircleBtn({required IconData icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 25,
        height: 25,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: onTap == null ? null : AppColors.goldGradient,
          color: onTap == null ? Colors.white12 : null,
          boxShadow: onTap == null
              ? null
              : const [BoxShadow(color: Color(0xFF261002), offset: Offset(0, 1.5))],
        ),
        child: Icon(
          icon,
          size: 15,
          color: onTap == null ? Colors.white30 : const Color(0xFF1B0733),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HERO 3D ARCADE SPIN BUTTON
  // ---------------------------------------------------------------------------
  Widget _buildHeroSpinButton() {
    final isFree = _freeSpins > 0;
    final isSpinning = _spinning;

    String label;
    Gradient gradient;
    Color rimColor;

    if (isSpinning) {
      label = 'STOP';
      gradient = const LinearGradient(
        colors: [Color(0xFFFF5252), Color(0xFFB71C1C)],
      );
      rimColor = const Color(0xFFFF8A80);
    } else if (isFree) {
      label = 'FREE SPIN';
      gradient = const LinearGradient(
        colors: [AppColors.teal, Color(0xFF7B1FA2)],
      );
      rimColor = AppColors.teal;
    } else {
      label = 'SPIN';
      gradient = AppColors.goldGradient;
      rimColor = const Color(0xFFFFF3B0);
    }

    final double translateY = _spinPressed ? 2.5 : 0.0;

    return GestureDetector(
      onTapDown: (_) => setState(() => _spinPressed = true),
      onTapUp: (_) {
        setState(() => _spinPressed = false);
        _spin();
      },
      onTapCancel: () => setState(() => _spinPressed = false),
      child: Transform.translate(
        offset: Offset(0, translateY),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: rimColor, width: 2),
            gradient: gradient,
            boxShadow: [
              BoxShadow(
                color: (isSpinning ? Colors.red : AppColors.gold)
                    .withValues(alpha: 0.55),
                blurRadius: 10,
                offset: Offset(0, _spinPressed ? 1 : 4),
              ),
              const BoxShadow(
                color: Color(0xFF170402),
                offset: Offset(0, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: 0,
                left: 10,
                right: 10,
                height: 18,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.45),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isSpinning
                        ? Icons.pause_circle_filled_rounded
                        : (isFree ? Icons.auto_awesome_rounded : Icons.casino_rounded),
                    color: isSpinning ? Colors.white : const Color(0xFF1F0833),
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: isSpinning ? Colors.white : const Color(0xFF1F0833),
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 1,
                      shadows: [
                        Shadow(
                          color: Colors.white.withValues(alpha: 0.4),
                          offset: const Offset(0, 1),
                          blurRadius: 1,
                        ),
                      ],
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
  // 6. PAYTABLE & RULES MODAL
  // ---------------------------------------------------------------------------
  void _showPaytable() {
    sound.tap();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.72,
        decoration: BoxDecoration(
          color: const Color(0xFF14052B),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppColors.gold, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.3),
              blurRadius: 20,
            ),
          ],
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.stars_rounded, color: AppColors.gold, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.title.toUpperCase()} • PAYTABLE',
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.white12, height: 1),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F0A3D),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.teal.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.bolt_rounded, color: AppColors.teal, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'SPECIAL REEL FEATURES',
                              style: TextStyle(
                                color: AppColors.teal,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• WILD SYMBOL: Substitutes for all regular paying symbols and awards a 2x win multiplier!\n'
                          '• SCATTER SYMBOL: 3 or more Scatters anywhere award 10 Free Spins!\n'
                          '• ALL WINS: Evaluated on fixed active paylines multiplied by your line bet.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 11.5,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'SYMBOL PAYOUT MULTIPLIERS (x LINE BET)',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w900,
                      fontSize: 12.5,
                      letterSpacing: 0.5,
                    ),
                  ),

                  const SizedBox(height: 10),

                  for (final sym in c.symbols.where((s) => s.pays.isNotEmpty)) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A0735),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          if (sym.asset != null)
                            Image.asset(sym.asset!, width: 28, height: 28, cacheWidth: 84)
                          else
                            Text(sym.glyph, style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              sym.id.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          for (final cnt in [3, 4, 5])
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                '${cnt}x: ${sym.payFor(cnt)}x',
                                style: const TextStyle(
                                  color: AppColors.gold,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
