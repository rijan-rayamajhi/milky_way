import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../engine/slot_engine.dart';
import '../engine/slot_symbol.dart';
import '../services/wallet_service.dart';
import '../theme/app_theme.dart';
import '../widgets/cosmic_button.dart';
import '../widgets/currency_bar.dart';
import '../widgets/win_celebration.dart';

/// Reusable animated slot machine driven by a [SlotConfig].
/// Optional flags add per-game mechanics:
///  - [cascades]      : winning symbols vanish, new ones drop, multiplier ladder
///  - [expandingWild] : a wild on a middle reel fills the reel + grants a respin
///  - [stickyWildSpins]: landed wilds stay for N spins with a combined multiplier
class SlotMachine extends StatefulWidget {
  final String title;
  final SlotConfig config;
  final WalletService wallet;
  final bool cascades;
  final bool expandingWild;
  final int stickyWildSpins;

  const SlotMachine({
    super.key,
    required this.title,
    required this.config,
    required this.wallet,
    this.cascades = false,
    this.expandingWild = false,
    this.stickyWildSpins = 0,
  });

  @override
  State<SlotMachine> createState() => _SlotMachineState();
}

class _SlotMachineState extends State<SlotMachine> {
  static const _betLevels = [1, 2, 5, 10, 20]; // coins per line/way-unit
  static const _ladder = [1, 2, 3, 5]; // cascade multiplier ladder
  late final SlotEngine _engine;

  late List<List<SlotSymbol>> _display;
  List<bool> _reelSpinning = [];
  Set<int> _winCells = {};
  final Map<int, int> _sticky = {}; // cell -> spins remaining
  bool _spinning = false;
  int _betIndex = 0;
  int _freeSpins = 0;
  int _lastWin = 0;
  int _cascadeMult = 1;
  Timer? _shuffle;

  SlotConfig get c => widget.config;
  int get _betPerLine => _betLevels[_betIndex];
  int get _totalBet => _betPerLine * c.betMultiplier();

  @override
  void initState() {
    super.initState();
    _engine = SlotEngine(c);
    _display = _engine.randomGrid();
    _reelSpinning = List.filled(c.reels, false);
  }

  @override
  void dispose() {
    _shuffle?.cancel();
    super.dispose();
  }

  void _changeBet(int dir) {
    if (_spinning || _freeSpins > 0) return;
    setState(() =>
        _betIndex = (_betIndex + dir).clamp(0, _betLevels.length - 1));
  }

  void _spin() {
    if (_spinning) return;
    final free = _freeSpins > 0;
    if (!free) {
      if (!widget.wallet.spendCoins(_totalBet)) {
        _handleCantAfford();
        return;
      }
    } else {
      setState(() => _freeSpins--);
    }
    widget.wallet.addXp(5);

    // Build the settled grid, overlaying any sticky wilds first.
    final grid = _engine.randomGrid();
    if (widget.stickyWildSpins > 0) _applySticky(grid);

    setState(() {
      _spinning = true;
      _lastWin = 0;
      _cascadeMult = 1;
      _winCells = {};
      _reelSpinning = List.filled(c.reels, true);
    });

    _shuffle = Timer.periodic(const Duration(milliseconds: 60), (_) {
      setState(() {
        for (var r = 0; r < c.reels; r++) {
          if (_reelSpinning[r]) {
            _display[r] = List.generate(c.rows, (_) => _engine.pick());
          }
        }
      });
    });

    for (var r = 0; r < c.reels; r++) {
      Future.delayed(Duration(milliseconds: 500 + r * 230), () {
        if (!mounted) return;
        setState(() {
          _display[r] = grid[r];
          _reelSpinning[r] = false;
        });
        if (r == c.reels - 1) _afterStop(grid);
      });
    }
  }

  Future<void> _afterStop(List<List<SlotSymbol>> grid) async {
    _shuffle?.cancel();
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

  // ---- simple settle (lines / ways / sticky) ----
  void _settleOnce() {
    final e = _engine.evaluateGrid(_display, _betPerLine);
    var win = e.lineTotal;
    if (widget.stickyWildSpins > 0) {
      final m = _stickyMultiplier();
      win *= m;
      _cascadeMult = m; // reuse the ladder label to show the multiplier
    }
    _award(e.winCells, win, e);
  }

  // ---- cascades (#5 Lucky Nebula) ----
  Future<void> _runCascades() async {
    var step = 0;
    var totalWin = 0;
    Set<int> lastCells = {};
    while (true) {
      final e = _engine.evaluateGrid(_display, _betPerLine);
      if (e.wins.isEmpty) {
        // still pay scatter on the first pass
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
      await Future.delayed(const Duration(milliseconds: 550));
      _collapse(e.winCells);
      setState(() {});
      await Future.delayed(const Duration(milliseconds: 250));
      step++;
    }
    setState(() {
      _winCells = lastCells;
      _lastWin = totalWin;
    });
    if (totalWin > 0) widget.wallet.addCoins(totalWin);
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

  // ---- expanding wild + respin (#4 Starburst Nova) ----
  Future<void> _runExpanding() async {
    var totalWin = 0;
    var respins = 0;
    const maxRespins = 3;
    while (true) {
      // Expand any wild on the middle reels to fill its reel.
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
      // A win with an expanded wild grants one respin.
      if (expanded && respins < maxRespins && e.wins.isNotEmpty) {
        respins++;
        await Future.delayed(const Duration(milliseconds: 650));
        _respinNonWildReels();
        await Future.delayed(const Duration(milliseconds: 200));
        continue;
      }
      break;
    }
    if (totalWin > 0) widget.wallet.addCoins(totalWin);
  }

  void _respinNonWildReels() {
    for (var reel = 0; reel < c.reels; reel++) {
      final allWild = _display[reel].every((s) => s.isWild);
      if (!allWild) _display[reel] = List.generate(c.rows, (_) => _engine.pick());
    }
    setState(() {});
  }

  // ---- sticky wilds (#6 Asteroid Blitz) ----
  void _applySticky(List<List<SlotSymbol>> grid) {
    for (final cell in _sticky.keys) {
      grid[cell ~/ c.rows][cell % c.rows] = c.wild;
    }
    // New wild landings become sticky.
    for (var reel = 0; reel < c.reels; reel++) {
      for (var row = 0; row < c.rows; row++) {
        if (grid[reel][row].isWild) {
          _sticky[reel * c.rows + row] = widget.stickyWildSpins;
        }
      }
    }
  }

  int _stickyMultiplier() =>
      _sticky.isEmpty ? 1 : min(1 + _sticky.length, 10); // ponytail: linear cap

  void _ageSticky() {
    // Sticky wilds persist for free spins; otherwise they age out.
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

  // ---- shared award / finish ----
  void _award(Set<int> cells, int win, GridEval e) {
    setState(() {
      _winCells = cells;
      _lastWin = win;
    });
    if (win > 0) widget.wallet.addCoins(win);
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
    if (tier != WinTier.none) showWinCelebration(context, _lastWin, tier);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/lobby/lobby_background.png',
              fit: BoxFit.cover),
          Container(color: AppColors.navy.withValues(alpha: 0.55)),
          SafeArea(
            child: Column(
              children: [
                _header(),
                const Spacer(),
                _reels(),
                const SizedBox(height: 12),
                _winRow(),
                const Spacer(),
                _controls(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(widget.title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
          ),
          SizedBox(
            width: 150,
            child: ListenableBuilder(
              listenable: widget.wallet,
              builder: (context, _) => Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Image.asset('assets/images/currency/coin.png',
                      width: 24, height: 24),
                  const SizedBox(width: 6),
                  Text(CurrencyBar.format(widget.wallet.coins),
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reels() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppColors.gold.withValues(alpha: 0.7), width: 2),
        boxShadow: [
          BoxShadow(color: AppColors.gold.withValues(alpha: 0.3), blurRadius: 18),
        ],
      ),
      child: AspectRatio(
        aspectRatio: c.reels / c.rows,
        child: Row(
          children: [
            for (var reel = 0; reel < c.reels; reel++)
              Expanded(
                child: Column(
                  children: [
                    for (var row = 0; row < c.rows; row++)
                      Expanded(child: _cell(reel, row)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cell(int reel, int row) {
    final sym = _display[reel][row];
    final win = _winCells.contains(reel * c.rows + row) && !_spinning;
    return PulseGlow(
      active: win,
      child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            sym.color.withValues(alpha: win ? 0.55 : 0.28),
            AppColors.deepPurple.withValues(alpha: 0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: win ? AppColors.gold : Colors.white.withValues(alpha: 0.12),
          width: win ? 2.5 : 1,
        ),
        boxShadow: win
            ? [BoxShadow(color: AppColors.gold.withValues(alpha: 0.6), blurRadius: 10)]
            : null,
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Text(
              sym.glyph,
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: sym.pays.isEmpty || sym.glyph.length > 1
                    ? Colors.white
                    : sym.color,
                shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }

  Widget _winRow() {
    final showWin = _lastWin > 0 && !_spinning;
    final showMult = _cascadeMult > 1;
    return SizedBox(
      height: 34,
      child: Column(
        children: [
          if (_freeSpins > 0)
            Text('FREE SPINS: $_freeSpins',
                style: const TextStyle(
                    color: AppColors.teal,
                    fontWeight: FontWeight.w900,
                    fontSize: 16)),
          if (showWin)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CountUpText(
                  key: ValueKey(_lastWin),
                  amount: _lastWin,
                  prefix: 'WIN  +',
                  style: const TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w900,
                      fontSize: 20),
                ),
                if (showMult)
                  Text('   x$_cascadeMult',
                      style: const TextStyle(
                          color: AppColors.teal,
                          fontWeight: FontWeight.w900,
                          fontSize: 20)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _controls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _betStepper(),
          const SizedBox(width: 16),
          Expanded(
            child: CosmicButton(
              label: _spinning
                  ? 'SPINNING…'
                  : (_freeSpins > 0 ? 'FREE SPIN' : 'SPIN'),
              icon: Icons.casino,
              height: 60,
              gradient: _freeSpins > 0
                  ? const LinearGradient(
                      colors: [AppColors.teal, AppColors.purple])
                  : AppColors.goldGradient,
              onTap: _spinning ? null : _spin,
            ),
          ),
        ],
      ),
    );
  }

  Widget _betStepper() {
    final locked = _spinning || _freeSpins > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('BET',
              style: TextStyle(color: AppColors.textDim, fontSize: 10)),
          Row(
            children: [
              _stepBtn(Icons.remove, locked ? null : () => _changeBet(-1)),
              SizedBox(
                width: 54,
                child: Text(CurrencyBar.format(_totalBet),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800)),
              ),
              _stepBtn(Icons.add, locked ? null : () => _changeBet(1)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          gradient: onTap == null ? null : AppColors.goldGradient,
          color: onTap == null ? Colors.white12 : null,
          shape: BoxShape.circle,
        ),
        child: Icon(icon,
            size: 18, color: onTap == null ? Colors.white38 : AppColors.navy),
      ),
    );
  }
}
