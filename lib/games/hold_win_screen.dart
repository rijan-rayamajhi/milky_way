import 'dart:math';
import 'package:flutter/material.dart';
import '../services/wallet_service.dart';
import '../theme/app_theme.dart';
import '../widgets/cosmic_button.dart';
import '../widgets/currency_bar.dart';

/// #3 Galaxy Gold — Hold & Win. Land 6+ coins to start 3 respins; each new
/// coin re-locks and resets respins. Fill all 15 cells for the Grand jackpot.
class HoldWinScreen extends StatefulWidget {
  final String title;
  final WalletService wallet;
  const HoldWinScreen({super.key, required this.title, required this.wallet});

  @override
  State<HoldWinScreen> createState() => _HoldWinScreenState();
}

class _Coin {
  final int value; // in coins
  final String? jackpot; // 'MINI' / 'MINOR' / 'MAJOR' / 'GRAND'
  const _Coin(this.value, [this.jackpot]);
}

class _HoldWinScreenState extends State<HoldWinScreen> {
  static const _betLevels = [1, 2, 5, 10, 20];
  static const reels = 5, rows = 3, cells = reels * rows;
  static const triggerCoins = 6;
  final _rng = Random();

  List<_Coin?> _grid = List.filled(cells, null);
  int _betIndex = 0;
  bool _busy = false;
  int _respins = 0;
  int _lastWin = 0;
  String _status = 'Land 6+ coins to win!';

  int get _betPerLine => _betLevels[_betIndex];
  int get _totalBet => _betPerLine * 25;

  void _changeBet(int dir) {
    if (_busy) return;
    setState(() => _betIndex = (_betIndex + dir).clamp(0, _betLevels.length - 1));
  }

  /// Weighted coin value. Rare high values + jackpot coins.
  _Coin _makeCoin() {
    final r = _rng.nextInt(100);
    if (r < 2) return _Coin(500 * _totalBet, 'MAJOR');
    if (r < 8) return _Coin(100 * _totalBet, 'MINOR');
    if (r < 18) return _Coin(20 * _totalBet, 'MINI');
    const bases = [1, 1, 1, 2, 2, 3, 5, 10, 15];
    return _Coin(bases[_rng.nextInt(bases.length)] * _totalBet);
  }

  Future<void> _spin() async {
    if (_busy) return;
    if (!widget.wallet.spendCoins(_totalBet)) {
      _cantAfford();
      return;
    }
    widget.wallet.addXp(5);
    setState(() {
      _busy = true;
      _lastWin = 0;
      _respins = 0;
      _grid = List.filled(cells, null);
      _status = 'Spinning…';
    });
    await Future.delayed(const Duration(milliseconds: 500));

    // Initial drop: ~18% chance of a coin per cell.
    final fresh = List<_Coin?>.generate(
        cells, (_) => _rng.nextInt(100) < 18 ? _makeCoin() : null);
    setState(() => _grid = fresh);
    final coinCount = fresh.where((c) => c != null).length;
    await Future.delayed(const Duration(milliseconds: 400));

    if (coinCount >= triggerCoins) {
      await _holdAndWin();
    } else {
      setState(() {
        _busy = false;
        _status = 'Land 6+ coins to win!';
      });
    }
  }

  Future<void> _holdAndWin() async {
    _respins = 3;
    setState(() => _status = '🎉 HOLD & WIN!');
    await Future.delayed(const Duration(milliseconds: 600));

    while (_respins > 0 && _grid.any((c) => c == null)) {
      setState(() => _respins--);
      await Future.delayed(const Duration(milliseconds: 500));
      var landed = false;
      for (var i = 0; i < cells; i++) {
        if (_grid[i] == null && _rng.nextInt(100) < 12) {
          _grid[i] = _makeCoin();
          landed = true;
        }
      }
      if (landed) _respins = 3; // reset on any new coin
      setState(() {});
    }

    var win = _grid.fold<int>(0, (a, c) => a + (c?.value ?? 0));
    final full = _grid.every((c) => c != null);
    if (full) win += 5000 * _totalBet; // GRAND
    widget.wallet.addCoins(win);
    setState(() {
      _busy = false;
      _lastWin = win;
      _status = full ? '🌟 GRAND JACKPOT!' : 'WIN +${CurrencyBar.format(win)}';
    });
  }

  void _cantAfford() {
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
                }),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough coins — lower your bet')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/lobby/lobby_background.png', fit: BoxFit.cover),
          Container(color: AppColors.navy.withValues(alpha: 0.55)),
          SafeArea(
            child: Column(
              children: [
                _header(),
                _jackpotBar(),
                const Spacer(),
                _board(),
                const SizedBox(height: 10),
                _statusRow(),
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

  Widget _header() => Padding(
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
                      color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            ListenableBuilder(
              listenable: widget.wallet,
              builder: (context, _) => Row(
                children: [
                  Image.asset('assets/images/currency/coin.png', width: 24, height: 24),
                  const SizedBox(width: 6),
                  Text(CurrencyBar.format(widget.wallet.coins),
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _jackpotBar() {
    Widget chip(String name, int mult, Color color) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.7)),
            ),
            child: Column(
              children: [
                Text(name,
                    style: TextStyle(
                        color: color, fontSize: 9, fontWeight: FontWeight.w800)),
                Text(CurrencyBar.format(mult * _totalBet),
                    style: const TextStyle(color: Colors.white, fontSize: 11)),
              ],
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          chip('MINI', 20, AppColors.teal),
          chip('MINOR', 100, Color(0xFF3DE08A)),
          chip('MAJOR', 500, AppColors.magenta),
          chip('GRAND', 5000, AppColors.gold),
        ],
      ),
    );
  }

  Widget _board() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.7), width: 2),
      ),
      child: AspectRatio(
        aspectRatio: reels / rows,
        child: Row(
          children: [
            for (var reel = 0; reel < reels; reel++)
              Expanded(
                child: Column(
                  children: [
                    for (var row = 0; row < rows; row++)
                      Expanded(child: _cell(reel * rows + row)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cell(int i) {
    final coin = _grid[i];
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: coin == null
            ? AppColors.deepPurple.withValues(alpha: 0.5)
            : AppColors.gold.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: coin == null
              ? Colors.white.withValues(alpha: 0.1)
              : AppColors.gold,
          width: coin == null ? 1 : 2,
        ),
      ),
      child: coin == null
          ? const SizedBox.shrink()
          : Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/images/currency/coin.png',
                          width: 30, height: 30),
                      Text(
                        coin.jackpot ?? CurrencyBar.format(coin.value),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _statusRow() => SizedBox(
        height: 30,
        child: Column(
          children: [
            if (_respins > 0)
              Text('RESPINS: $_respins',
                  style: const TextStyle(
                      color: AppColors.teal,
                      fontWeight: FontWeight.w900,
                      fontSize: 16))
            else
              Text(_status,
                  style: TextStyle(
                      color: _lastWin > 0 ? AppColors.gold : Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16)),
          ],
        ),
      );

  Widget _controls() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            _betStepper(),
            const SizedBox(width: 16),
            Expanded(
              child: CosmicButton(
                label: _busy ? 'SPINNING…' : 'SPIN',
                icon: Icons.casino,
                height: 60,
                onTap: _busy ? null : _spin,
              ),
            ),
          ],
        ),
      );

  Widget _betStepper() {
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
              _stepBtn(Icons.remove, _busy ? null : () => _changeBet(-1)),
              SizedBox(
                width: 54,
                child: Text(CurrencyBar.format(_totalBet),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800)),
              ),
              _stepBtn(Icons.add, _busy ? null : () => _changeBet(1)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback? onTap) => GestureDetector(
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
