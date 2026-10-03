import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../engine/slot_engine.dart';
import '../engine/slot_symbol.dart';
import '../services/wallet_service.dart';
import '../theme/app_theme.dart';
import '../widgets/cosmic_button.dart';
import '../widgets/currency_bar.dart';

/// Reusable animated slot machine driven by a [SlotConfig].
/// All 5 games render through this; only their config differs.
class SlotMachine extends StatefulWidget {
  final String title;
  final SlotConfig config;
  final WalletService wallet;

  const SlotMachine({
    super.key,
    required this.title,
    required this.config,
    required this.wallet,
  });

  @override
  State<SlotMachine> createState() => _SlotMachineState();
}

class _SlotMachineState extends State<SlotMachine> {
  static const _betLevels = [1, 2, 5, 10, 20]; // coins per line
  final _rng = Random();
  late final SlotEngine _engine;

  late List<List<SlotSymbol>> _display;
  List<bool> _reelSpinning = [];
  Set<int> _winCells = {}; // reel*rows + row
  bool _spinning = false;
  int _betIndex = 0;
  int _freeSpins = 0;
  int _lastWin = 0;
  Timer? _shuffle;

  SlotConfig get c => widget.config;
  int get _betPerLine => _betLevels[_betIndex];
  int get _totalBet => _betPerLine * c.paylines.length;

  @override
  void initState() {
    super.initState();
    _engine = SlotEngine(c);
    _display = List.generate(
        c.reels, (_) => List.generate(c.rows, (_) => _randomSymbol()));
    _reelSpinning = List.filled(c.reels, false);
  }

  @override
  void dispose() {
    _shuffle?.cancel();
    super.dispose();
  }

  SlotSymbol _randomSymbol() => c.symbols[_rng.nextInt(c.symbols.length)];

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

    final outcome = _engine.spin(_betPerLine);
    setState(() {
      _spinning = true;
      _lastWin = 0;
      _winCells = {};
      _reelSpinning = List.filled(c.reels, true);
    });

    // Blur-spin illusion: shuffle visible symbols while reels "spin".
    _shuffle = Timer.periodic(const Duration(milliseconds: 60), (_) {
      setState(() {
        for (var r = 0; r < c.reels; r++) {
          if (_reelSpinning[r]) {
            _display[r] = List.generate(c.rows, (_) => _randomSymbol());
          }
        }
      });
    });

    // Stop reels left-to-right, revealing the real outcome.
    for (var r = 0; r < c.reels; r++) {
      Future.delayed(Duration(milliseconds: 500 + r * 230), () {
        if (!mounted) return;
        setState(() {
          _display[r] = outcome.grid[r];
          _reelSpinning[r] = false;
        });
        if (r == c.reels - 1) _finish(outcome);
      });
    }
  }

  void _finish(SpinOutcome o) {
    _shuffle?.cancel();
    final winCells = <int>{};
    for (final w in o.lineWins) {
      final line = c.paylines[w.line];
      for (var reel = 0; reel < w.count; reel++) {
        winCells.add(reel * c.rows + line[reel]);
      }
    }
    if (o.scatterCount > 0) {
      for (var reel = 0; reel < c.reels; reel++) {
        for (var row = 0; row < c.rows; row++) {
          if (o.grid[reel][row].isScatter) winCells.add(reel * c.rows + row);
        }
      }
    }
    setState(() {
      _spinning = false;
      _lastWin = o.totalWin;
      _winCells = winCells;
      if (o.freeSpinsAwarded > 0) _freeSpins += o.freeSpinsAwarded;
    });
    if (o.totalWin > 0) widget.wallet.addCoins(o.totalWin);

    if (o.freeSpinsAwarded > 0) {
      _banner('🌌 ${o.freeSpinsAwarded} FREE SPINS!');
    } else if (o.totalWin >= _totalBet * 15) {
      _banner('💥 MEGA WIN  +${o.totalWin}');
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
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.7), width: 2),
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
    final win = _winCells.contains(reel * c.rows + row);
    return AnimatedContainer(
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
    );
  }

  Widget _winRow() {
    final showWin = _lastWin > 0 && !_spinning;
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
            Text('WIN  +${CurrencyBar.format(_lastWin)}',
                style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w900,
                    fontSize: 20)),
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
          const Text('BET', style: TextStyle(color: AppColors.textDim, fontSize: 10)),
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
