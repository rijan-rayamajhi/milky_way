import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../engine/slot_engine.dart' show betLevelsForBalance;
import '../services/engagement_service.dart';
import '../services/jackpot_service.dart';
import '../services/real_play_service.dart';
import '../services/sound_service.dart';
import '../services/wallet_service.dart';
import '../theme/app_theme.dart';
import '../widgets/coin_fly_overlay.dart';
import '../widgets/cosmic_button.dart';
import '../widgets/currency_bar.dart';
import '../widgets/win_celebration.dart';

/// Galaxy Gold Symbol definition.
class _GalaxySymbol {
  final String id;
  final String name;
  final String asset;
  final Color color;
  final bool isCoin;
  final Map<int, int> pays; // match count -> line bet multiplier

  const _GalaxySymbol({
    required this.id,
    required this.name,
    required this.asset,
    required this.color,
    this.isCoin = false,
    this.pays = const {},
  });
}

/// A cell's current active item.
class _CellItem {
  final _GalaxySymbol symbol;
  final int coinValue; // only relevant if symbol.isCoin is true
  final String? jackpot; // 'MINI', 'MINOR', 'MAJOR', 'GRAND'
  final bool locked;

  const _CellItem({
    required this.symbol,
    this.coinValue = 0,
    this.jackpot,
    this.locked = false,
  });

  _CellItem copyWith({bool? locked}) => _CellItem(
        symbol: symbol,
        coinValue: coinValue,
        jackpot: jackpot,
        locked: locked ?? this.locked,
      );
}

/// #3 Galaxy Gold — Premier 5x3 Hold & Win Slot Game.
/// Base Game: 25 Paylines with full vibrant symbol assets.
/// Feature: Land 6+ Gold Coins anywhere to trigger HOLD & WIN 3 Respins!
/// Fill all 15 cells for the GRAND JACKPOT!
class HoldWinScreen extends StatefulWidget {
  final String title;
  final WalletService wallet;
  final EngagementService? engagement;
  final JackpotService? jackpots;
  final String background;
  const HoldWinScreen({
    super.key,
    required this.title,
    required this.wallet,
    this.engagement,
    this.jackpots,
    this.background = 'assets/images/lobby/lobby_background.png',
  });

  @override
  State<HoldWinScreen> createState() => _HoldWinScreenState();
}

class _HoldWinScreenState extends State<HoldWinScreen> {
  static const reels = 5, rows = 3, cells = reels * rows;
  static const triggerCoins = 6;
  final _rng = Random();

  // All 10 Game Symbols with rich assets
  static const _symCrown = _GalaxySymbol(
    id: 'crown',
    name: 'Crown',
    asset: 'assets/images/symbols/lucky_nebula/crown.png',
    color: AppColors.gold,
    pays: {3: 8, 4: 25, 5: 60},
  );
  static const _symHorseshoe = _GalaxySymbol(
    id: 'horseshoe',
    name: 'Horseshoe',
    asset: 'assets/images/symbols/lucky_nebula/horseshoe.png',
    color: Color(0xFFFFB13D),
    pays: {3: 6, 4: 18, 5: 45},
  );
  static const _symPlanet = _GalaxySymbol(
    id: 'planet',
    name: 'Planet',
    asset: 'assets/images/symbols/cosmic_fortune/planet.png',
    color: Color(0xFF3DD7FF),
    pays: {3: 5, 4: 14, 5: 35},
  );
  static const _symStar = _GalaxySymbol(
    id: 'star',
    name: 'Star',
    asset: 'assets/images/symbols/cosmic_fortune/star.png',
    color: Color(0xFFFF5A5A),
    pays: {3: 4, 4: 10, 5: 25},
  );
  static const _symA = _GalaxySymbol(
    id: 'a',
    name: 'Ace',
    asset: 'assets/images/symbols/royals/a.png',
    color: Color(0xFFFF7BD5),
    pays: {3: 2, 4: 6, 5: 15},
  );
  static const _symK = _GalaxySymbol(
    id: 'k',
    name: 'King',
    asset: 'assets/images/symbols/royals/k.png',
    color: Color(0xFF7BC4FF),
    pays: {3: 2, 4: 5, 5: 12},
  );
  static const _symQ = _GalaxySymbol(
    id: 'q',
    name: 'Queen',
    asset: 'assets/images/symbols/royals/q.png',
    color: Color(0xFF8CF0C0),
    pays: {3: 1, 4: 4, 5: 10},
  );
  static const _symJ = _GalaxySymbol(
    id: 'j',
    name: 'Jack',
    asset: 'assets/images/symbols/royals/j.png',
    color: Color(0xFFC9B8FF),
    pays: {3: 1, 4: 3, 5: 8},
  );
  static const _sym10 = _GalaxySymbol(
    id: '10',
    name: 'Ten',
    asset: 'assets/images/symbols/royals/ten.png',
    color: Color(0xFFBFC6E0),
    pays: {3: 1, 4: 3, 5: 8},
  );
  static const _symCoin = _GalaxySymbol(
    id: 'coin',
    name: 'Gold Coin',
    asset: 'assets/images/currency/coin.png',
    color: AppColors.gold,
    isCoin: true,
  );

  static const _regularSymbols = [
    _symCrown,
    _symHorseshoe,
    _symPlanet,
    _symStar,
    _symA,
    _symK,
    _symQ,
    _symJ,
    _sym10,
  ];

  // 25 Fixed Paylines for Base Game
  static const _paylines = [
    [1, 1, 1, 1, 1],
    [0, 0, 0, 0, 0],
    [2, 2, 2, 2, 2],
    [0, 1, 2, 1, 0],
    [2, 1, 0, 1, 2],
    [0, 0, 1, 2, 2],
    [2, 2, 1, 0, 0],
    [1, 2, 2, 2, 1],
    [1, 0, 0, 0, 1],
    [0, 1, 1, 1, 0],
    [2, 1, 1, 1, 2],
    [0, 1, 0, 1, 0],
    [2, 1, 2, 1, 2],
    [1, 0, 1, 0, 1],
    [1, 2, 1, 2, 1],
    [0, 0, 1, 0, 0],
    [2, 2, 1, 2, 2],
    [1, 1, 0, 1, 1],
    [1, 1, 2, 1, 1],
    [0, 2, 0, 2, 0],
    [2, 0, 2, 0, 2],
    [0, 2, 2, 2, 0],
    [2, 0, 0, 0, 2],
    [1, 0, 2, 0, 1],
    [1, 2, 0, 2, 1],
  ];

  late List<_CellItem> _grid;
  List<bool> _reelSpinning = List.filled(reels, false);
  Set<int> _winCells = {};
  int _betIndex = 0;
  bool _spinning = false;
  bool _inBonusMode = false;
  int _respins = 0;
  int _lastWin = 0;
  String _status = '✨ 25 PAYLINES ACTIVE • LAND 6+ COINS FOR BONUS ✨';

  bool _turbo = false;
  int _autoSpinsRemaining = 0;
  Timer? _jackpotTimer;
  int _jackpotTick = 0;
  int _lastSpinBet = 0;
  Timer? _shuffle;
  final List<Timer> _reelTimers = [];
  bool _spinPressed = false;

  // Total-bet levels (multiples of 50) scale with the player's balance.
  List<int> get _betLevels => betLevelsForBalance(widget.wallet.coins);
  int get _betIndexClamped => _betIndex.clamp(0, _betLevels.length - 1);
  int get _totalBet => _betLevels[_betIndexClamped];
  int get _betPerLine => _totalBet ~/ 25;
  bool get _isMaxBet => _betIndexClamped == _betLevels.length - 1;

  @override
  void initState() {
    super.initState();
    // Initialize with full rich visible symbols so the screen is never blank!
    _grid = List.generate(cells, (_) => _randomBaseItem());

    _jackpotTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        setState(() => _jackpotTick = (_jackpotTick + 23) % 10000);
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

  _CellItem _randomBaseItem() {
    // 16% chance of a special coin, 84% regular symbol
    if (_rng.nextInt(100) < 16) {
      return _generateCoinItem();
    }
    final sym = _regularSymbols[_rng.nextInt(_regularSymbols.length)];
    return _CellItem(symbol: sym);
  }

  _CellItem _generateCoinItem() {
    final r = _rng.nextInt(100);
    if (r < 2) {
      return _CellItem(
        symbol: _symCoin,
        coinValue: 500 * _totalBet,
        jackpot: 'MAJOR',
      );
    }
    if (r < 7) {
      return _CellItem(
        symbol: _symCoin,
        coinValue: 100 * _totalBet,
        jackpot: 'MINOR',
      );
    }
    if (r < 16) {
      return _CellItem(
        symbol: _symCoin,
        coinValue: 20 * _totalBet,
        jackpot: 'MINI',
      );
    }
    const multipliers = [1, 2, 3, 5, 8, 10, 15];
    final mult = multipliers[_rng.nextInt(multipliers.length)];
    return _CellItem(
      symbol: _symCoin,
      coinValue: mult * _totalBet,
    );
  }

  void _changeBet(int dir) {
    if (_spinning || _inBonusMode) return;
    sound.tap();
    setState(() => _betIndex = (_betIndexClamped + dir).clamp(0, _betLevels.length - 1));
  }

  void _maxBet() {
    if (_spinning || _inBonusMode || _isMaxBet) return;
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

    if (_autoSpinsRemaining > 0 && !_spinning && !_inBonusMode) {
      _spin();
    }
  }

  void _cancelAutoSpin() {
    if (_autoSpinsRemaining > 0) {
      setState(() => _autoSpinsRemaining = 0);
    }
  }

  void _spin() {
    if (_spinning) return;

    if (_inBonusMode) {
      _executeBonusRespin();
      return;
    }

    if (!widget.wallet.spendCoins(_totalBet)) {
      _cancelAutoSpin();
      _handleCantAfford();
      return;
    }

    _lastSpinBet = _totalBet;
    // Every paid spin seeds the progressive jackpot pools.
    widget.jackpots?.contribute(_totalBet);
    sound.spinStart();
    _cancelReelTimers();

    setState(() {
      _spinning = true;
      _lastWin = 0;
      _winCells = {};
      _status = '⚡ REELS IN MOTION...';
      _reelSpinning = List.filled(reels, true);
    });

    // Animate spinning reels
    _shuffle = Timer.periodic(const Duration(milliseconds: 55), (_) {
      if (!mounted) return;
      setState(() {
        for (var reel = 0; reel < reels; reel++) {
          if (_reelSpinning[reel]) {
            for (var row = 0; row < rows; row++) {
              _grid[reel * rows + row] = _randomBaseItem();
            }
          }
        }
      });
    });

    // Build settled outcome
    final targetGrid = List<_CellItem>.generate(cells, (_) => _randomBaseItem());

    final baseDelay = _turbo ? 180 : 450;
    final stepDelay = _turbo ? 90 : 200;

    for (var r = 0; r < reels; r++) {
      final t = Timer(Duration(milliseconds: baseDelay + r * stepDelay), () {
        if (!mounted || !_spinning) return;
        setState(() {
          for (var row = 0; row < rows; row++) {
            _grid[r * rows + row] = targetGrid[r * rows + row];
          }
          _reelSpinning[r] = false;
        });
        sound.reelStop();
        if (r == reels - 1) _afterStop(targetGrid);
      });
      _reelTimers.add(t);
    }
  }

  void _afterStop(List<_CellItem> targetGrid) async {
    _shuffle?.cancel();
    _cancelReelTimers();
    sound.spinStop();

    // Check coin count for Hold & Win trigger
    final coinIndexes = <int>[];
    for (var i = 0; i < cells; i++) {
      if (targetGrid[i].symbol.isCoin) coinIndexes.add(i);
    }

    if (coinIndexes.length >= triggerCoins) {
      // Trigger Hold & Win!
      _triggerHoldAndWin(coinIndexes);
      return;
    }

    // Normal Base Game Payline Evaluation
    _evaluateBasePaylines();
  }

  void _evaluateBasePaylines() {
    var lineWinTotal = 0;
    final winningCellSet = <int>{};

    for (final line in _paylines) {
      final firstCell = 0 * rows + line[0];
      final firstSym = _grid[firstCell].symbol;
      if (firstSym.isCoin) continue;

      var matchCount = 1;
      final lineCells = [firstCell];

      for (var r = 1; r < reels; r++) {
        final cellIdx = r * rows + line[r];
        final sym = _grid[cellIdx].symbol;
        if (sym.id == firstSym.id) {
          matchCount++;
          lineCells.add(cellIdx);
        } else {
          break;
        }
      }

      if (matchCount >= 3) {
        final mult = firstSym.pays[matchCount] ?? 0;
        final payout = mult * _betPerLine;
        lineWinTotal += payout;
        winningCellSet.addAll(lineCells);
      }
    }

    setState(() {
      _spinning = false;
      _winCells = winningCellSet;
      _lastWin = lineWinTotal;
      if (lineWinTotal > 0) {
        _status = '★ LINE WIN: +${CurrencyBar.format(lineWinTotal)} COINS! ★';
      } else {
        _status = '✨ 25 PAYLINES ACTIVE • LAND 6+ COINS FOR BONUS ✨';
      }
    });

    // Record the completed base spin (stats, bet-scaled XP, missions).
    widget.wallet.recordSpin(bet: _lastSpinBet, win: lineWinTotal);
    widget.engagement?.recordSpins(1);

    if (lineWinTotal > 0) {
      widget.wallet.addCoins(lineWinTotal, origin: _getReelOrigin());
      widget.engagement?.recordWinCoins(lineWinTotal);
      final tier = winTierFor(lineWinTotal, _totalBet);
      if (tier != WinTier.none) {
        widget.engagement?.recordBigWin();
        sound.bigWin();
        showWinCelebration(context, lineWinTotal, tier);
      } else {
        sound.win();
      }
    }

    // Auto-spin sequencing
    if (_autoSpinsRemaining > 0 && mounted) {
      setState(() => _autoSpinsRemaining--);
      if (_autoSpinsRemaining > 0) {
        Future.delayed(Duration(milliseconds: _turbo ? 350 : 650), () {
          if (mounted && _autoSpinsRemaining > 0 && !_spinning && !_inBonusMode) {
            _spin();
          }
        });
      }
    }
  }

  Offset _getReelOrigin() {
    final size = MediaQuery.sizeOf(context);
    return Offset(size.width * 0.5, size.height * 0.38);
  }

  void _triggerHoldAndWin(List<int> triggeringCoinIndexes) async {
    _cancelAutoSpin();
    sound.bigWin();
    setState(() {
      _spinning = false;
      _inBonusMode = true;
      _respins = 3;
      _status = '🎉 HOLD & WIN TRIGGERED! 3 RESPINS REMAINING!';
      // Lock the triggering coins; convert non-coin positions into un-locked bonus sockets
      for (var i = 0; i < cells; i++) {
        if (triggeringCoinIndexes.contains(i)) {
          _grid[i] = _grid[i].copyWith(locked: true);
        } else {
          // Placeholder coin-socket item for bonus mode
          _grid[i] = _CellItem(symbol: _symCoin, coinValue: 0, locked: false);
        }
      }
    });
  }

  void _executeBonusRespin() async {
    if (_respins <= 0) return;

    sound.spinStart();
    setState(() {
      _spinning = true;
      _respins--;
      _status = '🔥 RESPINNING UNLOCKED VAULT CELLS...';
    });

    await Future.delayed(Duration(milliseconds: _turbo ? 300 : 600));

    var newCoinLanded = false;
    final newGrid = List<_CellItem>.from(_grid);

    for (var i = 0; i < cells; i++) {
      if (!newGrid[i].locked) {
        // 14% chance a new coin lands
        if (_rng.nextInt(100) < 14) {
          final coin = _generateCoinItem();
          newGrid[i] = coin.copyWith(locked: true);
          newCoinLanded = true;
        }
      }
    }

    sound.spinStop();
    sound.reelStop();

    if (newCoinLanded) {
      _respins = 3; // Reset respins to 3 upon any new coin hit!
      sound.win();
    }

    setState(() {
      _spinning = false;
      _grid = newGrid;
      if (newCoinLanded) {
        _status = '🎉 NEW COIN LOCKED! RESPINS RESET TO 3!';
      } else {
        _status = '🔥 RESPINS REMAINING: $_respins';
      }
    });

    final allLocked = _grid.every((c) => c.locked && c.coinValue > 0);

    if (allLocked || _respins == 0) {
      // Bonus Round Concluded
      await Future.delayed(const Duration(milliseconds: 700));
      _concludeHoldAndWin(isFullGridGrand: allLocked);
    }
  }

  void _concludeHoldAndWin({required bool isFullGridGrand}) {
    var totalPrize =
        _grid.fold<int>(0, (sum, c) => sum + (c.locked ? c.coinValue : 0));

    final jp = widget.jackpots;
    if (jp != null) {
      // Award each real pooled jackpot whose coin landed, then reset it.
      final tiersHit = <JackpotTier>{};
      for (final cell in _grid) {
        if (!cell.locked) continue;
        switch (cell.jackpot) {
          case 'MINI':
            tiersHit.add(JackpotTier.mini);
          case 'MINOR':
            tiersHit.add(JackpotTier.minor);
          case 'MAJOR':
            tiersHit.add(JackpotTier.major);
        }
      }
      if (isFullGridGrand) tiersHit.add(JackpotTier.grand);
      for (final t in tiersHit) {
        totalPrize += jp.award(t);
      }
    } else if (isFullGridGrand) {
      totalPrize += 5000 * _totalBet; // fallback GRAND when no pool wired
    }

    widget.wallet.addCoins(totalPrize, origin: _getReelOrigin());
    widget.wallet.recordWin(totalPrize);
    widget.engagement?.recordWinCoins(totalPrize);
    widget.engagement?.recordBigWin();

    setState(() {
      _inBonusMode = false;
      _lastWin = totalPrize;
      _status = isFullGridGrand
          ? '🌟 GRAND JACKPOT UNLOCKED! +${CurrencyBar.format(totalPrize)} COINS!'
          : '★ HOLD & WIN COLLECTED: +${CurrencyBar.format(totalPrize)} COINS! ★';
      // Reset grid to rich base symbols
      _grid = List.generate(cells, (_) => _randomBaseItem());
    });

    final tier = isFullGridGrand ? WinTier.epic : winTierFor(totalPrize, _totalBet);
    sound.bigWin();
    if (mounted) {
      showWinCelebration(context, totalPrize, tier);
    }
  }

  void _handleCantAfford() {
    if (widget.wallet.isBroke) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.deepPurple,
          title: const Text('Out of Coins!', style: TextStyle(color: AppColors.gold)),
          content: Text('Collect ${WalletService.rescueAmount} coins to keep playing.',
              style: const TextStyle(color: Colors.white)),
          actions: [
            CosmicButton(
              label: 'Collect',
              onTap: () {
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
          Image.asset(widget.background, fit: BoxFit.cover),
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
                // 1. Arcade Header
                _buildArcadeHeader(),

                const SizedBox(height: 4),

                // 2. Progressive Jackpot Marquee
                _buildJackpotBar(),

                const Spacer(flex: 1),

                // 3. Physical Vegas Slot Cabinet (Snugly wrapping 5x3 reels)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: _buildCabinetBoard(),
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
  // 1. ARCADE HEADER BAR
  // ---------------------------------------------------------------------------
  Widget _buildArcadeHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
      child: Row(
        children: [
          _arcadeRoundBtn(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.pop(context),
            tooltip: 'Lobby',
          ),
          const SizedBox(width: 8),

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
                  _inBonusMode ? '★ HOLD & WIN FEATURE ACTIVE ★' : '25 PAYLINES • 6+ COINS HOLD & WIN',
                  style: TextStyle(
                    color: _inBonusMode ? const Color(0xFFFFF2A8) : AppColors.teal,
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
              icon: sound.anyAudioOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
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

          // Wallet Balance Chip
          ListenableBuilder(
            listenable: widget.wallet,
            builder: (context, _) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
              decoration: BoxDecoration(
                color: const Color(0xFF170932),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.7), width: 1.2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/images/currency/coin.png', width: 17, height: 17, cacheWidth: 60),
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
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.45), width: 1.2),
          boxShadow: const [
            BoxShadow(color: Color(0xFF0A0216), offset: Offset(0, 2), blurRadius: 0),
          ],
        ),
        child: Icon(icon, size: 15, color: iconColor),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. PROGRESSIVE JACKPOT MARQUEE
  // ---------------------------------------------------------------------------
  Widget _buildJackpotBar() {
    // Fallback multipliers used only when no shared jackpot pool is wired.
    const fallbackMult = {
      JackpotTier.mini: 20,
      JackpotTier.minor: 100,
      JackpotTier.major: 500,
      JackpotTier.grand: 5000,
    };
    const colors = {
      JackpotTier.mini: AppColors.teal,
      JackpotTier.minor: Color(0xFF00E676),
      JackpotTier.major: Color(0xFFE040FB),
      JackpotTier.grand: AppColors.gold,
    };

    Widget chip(JackpotTier t) {
      final isGrand = t == JackpotTier.grand;
      final color = colors[t]!;
      final jp = widget.jackpots;
      final value = jp != null
          ? jp.value(t)
          : fallbackMult[t]! * _totalBet + (_jackpotTick % (fallbackMult[t]! * 2 + 1));
      return Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2.5),
          padding: const EdgeInsets.symmetric(vertical: 3.5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: color.withValues(alpha: isGrand ? 0.9 : 0.4),
              width: isGrand ? 1.2 : 0.8,
            ),
            boxShadow: isGrand
                ? [BoxShadow(color: AppColors.gold.withValues(alpha: 0.35), blurRadius: 6)]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(JackpotService.labels[t]!,
                  style: TextStyle(
                      color: color, fontSize: 8.5, fontWeight: FontWeight.w900)),
              Text(
                CurrencyBar.format(value),
                style: TextStyle(
                  color: isGrand ? const Color(0xFFFFF2A8) : Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final bar = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          for (final t in JackpotTier.values) chip(t),
        ],
      ),
    );
    final jp = widget.jackpots;
    if (jp == null) return bar;
    return ListenableBuilder(listenable: jp, builder: (_, _) => bar);
  }

  // ---------------------------------------------------------------------------
  // 3. PHYSICAL VEGAS SLOT CABINET (Snug fit, large vibrant symbols!)
  // ---------------------------------------------------------------------------
  Widget _buildCabinetBoard() {
    return AspectRatio(
      aspectRatio: 1.55,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF120329),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.gold, width: 3.2),
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
              // Inner Grid
              Container(
                color: const Color(0xFF090214),
                child: Row(
                  children: [
                    for (var reel = 0; reel < reels; reel++) ...[
                      if (reel > 0)
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
                            for (var row = 0; row < rows; row++)
                              Expanded(child: _cell(reel * rows + row)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // 3D curved drum shadows
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _cell(int i) {
    final item = _grid[i];
    final isWinningLine = _winCells.contains(i);
    final isLockedCoin = item.symbol.isCoin && item.locked;
    final isBonusBlank = _inBonusMode && !item.locked;

    return PulseGlow(
      active: isWinningLine || isLockedCoin,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 2.5),
        decoration: BoxDecoration(
          color: isLockedCoin
              ? const Color(0xFF5A2A00).withValues(alpha: 0.70)
              : (isBonusBlank
                  ? const Color(0xFF13042A).withValues(alpha: 0.50)
                  : const Color(0xFF1C0A38).withValues(alpha: 0.75)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: (isLockedCoin || isWinningLine)
                ? AppColors.gold
                : (isBonusBlank ? Colors.white10 : Colors.white.withValues(alpha: 0.15)),
            width: (isLockedCoin || isWinningLine) ? 2.4 : 1,
          ),
          boxShadow: (isLockedCoin || isWinningLine)
              ? [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.8),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: isBonusBlank
            ? Center(
                child: Icon(
                  Icons.lock_open_rounded,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.18),
                ),
              )
            : Center(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: item.symbol.isCoin
                      // Gold Coin with cash multiplier badge
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset('assets/images/currency/coin.png', width: 34, height: 34, cacheWidth: 110),
                            const SizedBox(height: 1),
                            Text(
                              item.jackpot ?? CurrencyBar.format(item.coinValue),
                              style: TextStyle(
                                color: item.jackpot != null ? const Color(0xFFFFF2A8) : Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                shadows: const [Shadow(color: Colors.black, blurRadius: 3)],
                              ),
                            ),
                          ],
                        )
                      // Regular Symbol Asset (Crown, Horseshoe, Planet, Star, Royals)
                      : Image.asset(item.symbol.asset, fit: BoxFit.contain, cacheWidth: 200),
                ),
              ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. LED MATRIX DIGITAL STATUS MARQUEE
  // ---------------------------------------------------------------------------
  Widget _buildStatusMarquee() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF130429),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _inBonusMode || _lastWin > 0
                ? AppColors.gold
                : AppColors.gold.withValues(alpha: 0.35),
            width: _inBonusMode || _lastWin > 0 ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _inBonusMode ? Icons.local_fire_department_rounded : Icons.stars_rounded,
              size: 14,
              color: _inBonusMode ? AppColors.teal : AppColors.gold,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _status,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _inBonusMode
                      ? AppColors.teal
                      : (_lastWin > 0 ? AppColors.gold : Colors.white),
                  fontWeight: FontWeight.w900,
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
    final locked = _spinning;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF220B4A), Color(0xFF100326)],
        ),
        border: Border(top: BorderSide(color: AppColors.gold.withValues(alpha: 0.7), width: 1.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Utility Row
          Row(
            children: [
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
              Expanded(
                child: _utilityPillBtn(
                  label: _autoSpinsRemaining > 0 ? 'AUTO ($_autoSpinsRemaining)' : 'AUTO SPIN',
                  icon: Icons.sync_rounded,
                  active: _autoSpinsRemaining > 0,
                  onTap: locked || _inBonusMode ? _cancelAutoSpin : _cycleAutoSpin,
                  activeColor: const Color(0xFFE040FB),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _utilityPillBtn(
                  label: 'MAX BET',
                  icon: Icons.workspace_premium_rounded,
                  active: _isMaxBet,
                  onTap: locked || _inBonusMode || _isMaxBet ? null : _maxBet,
                  activeColor: AppColors.gold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Main Action Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF15042E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('TOTAL BET',
                        style: TextStyle(color: AppColors.textDim, fontSize: 8.5, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _stepCircleBtn(icon: Icons.remove, onTap: locked || _inBonusMode ? null : () => _changeBet(-1)),
                        SizedBox(
                          width: 52,
                          child: Text(
                            CurrencyBar.format(_totalBet),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900, fontSize: 14),
                          ),
                        ),
                        _stepCircleBtn(icon: Icons.add, onTap: locked || _inBonusMode ? null : () => _changeBet(1)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // 3D Hero Spin Button
              Expanded(
                child: GestureDetector(
                  onTapDown: (_) => setState(() => _spinPressed = true),
                  onTapUp: (_) {
                    setState(() => _spinPressed = false);
                    _spin();
                  },
                  onTapCancel: () => setState(() => _spinPressed = false),
                  child: Transform.translate(
                    offset: Offset(0, _spinPressed ? 2.5 : 0.0),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _inBonusMode ? AppColors.teal : const Color(0xFFFFF3B0),
                          width: 2,
                        ),
                        gradient: _inBonusMode
                            ? const LinearGradient(colors: [AppColors.teal, Color(0xFF7B1FA2)])
                            : AppColors.goldGradient,
                        boxShadow: [
                          BoxShadow(
                            color: (_inBonusMode ? AppColors.teal : AppColors.gold).withValues(alpha: 0.55),
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _inBonusMode ? Icons.local_fire_department_rounded : Icons.casino_rounded,
                            color: const Color(0xFF1F0833),
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _spinning
                                ? 'SPINNING…'
                                : (_inBonusMode ? 'RESPIN ($_respins)' : 'SPIN'),
                            style: const TextStyle(
                              color: Color(0xFF1F0833),
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
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
          color: active ? activeColor.withValues(alpha: 0.25) : const Color(0xFF15042E),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: active ? activeColor : AppColors.gold.withValues(alpha: 0.35),
            width: active ? 1.4 : 0.8,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: active ? activeColor : Colors.white60),
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
        ),
        child: Icon(icon, size: 15, color: onTap == null ? Colors.white30 : const Color(0xFF1B0733)),
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
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 44, height: 4, decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.stars_rounded, color: AppColors.gold, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.title.toUpperCase()} • PAYTABLE',
                    style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white70), onPressed: () => Navigator.pop(context)),
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
                            Text('HOLD & WIN MECHANIC', style: TextStyle(color: AppColors.teal, fontWeight: FontWeight.w900, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• Land 6 or more Gold Coins anywhere to trigger the HOLD & WIN Bonus!\n'
                          '• Initial 3 Respins granted. Every new coin resets respins back to 3!\n'
                          '• Lock all 15 positions to win the 5,000x GRAND JACKPOT!\n'
                          '• Normal spins evaluate 25 fixed paylines from left to right.',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11.5, height: 1.45),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('SYMBOL MULTIPLIERS (x LINE BET)', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900, fontSize: 12.5)),
                  const SizedBox(height: 10),
                  for (final sym in _regularSymbols)
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
                          Image.asset(sym.asset, width: 28, height: 28, cacheWidth: 84),
                          const SizedBox(width: 12),
                          Expanded(child: Text(sym.name.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12))),
                          for (final cnt in [3, 4, 5])
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text('${cnt}x: ${sym.pays[cnt]}x', style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w800, fontSize: 11.5)),
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
}
