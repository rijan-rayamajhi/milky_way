import 'dart:math';
import 'slot_symbol.dart';

/// Config for one slot game. The engine is generic; each game supplies this.
class SlotConfig {
  final int reels;
  final int rows;
  final List<SlotSymbol> symbols;
  final List<List<int>> paylines; // each: one row-index per reel
  final int wildMultiplier; // applied once when a wild joins a line win
  final int freeSpinScatters; // scatters needed to trigger free spins
  final int freeSpinCount; // free spins awarded
  final Map<int, int> scatterPays; // count -> x total bet

  const SlotConfig({
    required this.symbols,
    required this.paylines,
    this.reels = 5,
    this.rows = 3,
    this.wildMultiplier = 2,
    this.freeSpinScatters = 3,
    this.freeSpinCount = 10,
    this.scatterPays = const {3: 2, 4: 10, 5: 50},
  });

  SlotSymbol get wild => symbols.firstWhere((s) => s.isWild);
  SlotSymbol get scatter => symbols.firstWhere((s) => s.isScatter);
}

class LineWin {
  final int line;
  final SlotSymbol symbol;
  final int count;
  final int payout;
  final bool wildBoosted;
  const LineWin(this.line, this.symbol, this.count, this.payout, this.wildBoosted);
}

class SpinOutcome {
  final List<List<SlotSymbol>> grid; // [reel][row]
  final List<LineWin> lineWins;
  final int scatterCount;
  final int scatterPay;
  final int freeSpinsAwarded;
  final int totalWin;
  const SpinOutcome({
    required this.grid,
    required this.lineWins,
    required this.scatterCount,
    required this.scatterPay,
    required this.freeSpinsAwarded,
    required this.totalWin,
  });
}

class SlotEngine {
  final SlotConfig config;
  final Random _rng;
  late final List<int> _cumWeights;
  late final int _weightTotal;

  SlotEngine(this.config, {Random? rng}) : _rng = rng ?? Random() {
    var acc = 0;
    _cumWeights = [for (final s in config.symbols) acc += s.weight];
    _weightTotal = acc;
  }

  SlotSymbol _pick() {
    final r = _rng.nextInt(_weightTotal);
    for (var i = 0; i < _cumWeights.length; i++) {
      if (r < _cumWeights[i]) return config.symbols[i];
    }
    return config.symbols.last;
  }

  /// Independent weighted reels (good for classic paylines; cascades/ways
  /// layer on later games). [betPerLine] is coins per active payline.
  SpinOutcome spin(int betPerLine) {
    final grid = List.generate(
      config.reels,
      (_) => List.generate(config.rows, (_) => _pick()),
    );

    final lineWins = <LineWin>[];
    int total = 0;

    for (var l = 0; l < config.paylines.length; l++) {
      final line = config.paylines[l];
      final symbolsOnLine = [
        for (var reel = 0; reel < config.reels; reel++) grid[reel][line[reel]],
      ];
      final win = _evaluateLine(l, symbolsOnLine, betPerLine);
      if (win != null) {
        lineWins.add(win);
        total += win.payout;
      }
    }

    // Scatters pay anywhere on the grid.
    var scatters = 0;
    for (final reel in grid) {
      for (final s in reel) {
        if (s.isScatter) scatters++;
      }
    }
    final totalBet = betPerLine * config.paylines.length;
    final scatterPay = (config.scatterPays[scatters] ?? 0) * totalBet;
    final freeSpins =
        scatters >= config.freeSpinScatters ? config.freeSpinCount : 0;
    total += scatterPay;

    return SpinOutcome(
      grid: grid,
      lineWins: lineWins,
      scatterCount: scatters,
      scatterPay: scatterPay,
      freeSpinsAwarded: freeSpins,
      totalWin: total,
    );
  }

  /// Leftmost-consecutive evaluation with wild substitution.
  LineWin? _evaluateLine(int lineIndex, List<SlotSymbol> line, int betPerLine) {
    // Base symbol = first non-wild from the left (wilds substitute for it).
    SlotSymbol? base;
    for (final s in line) {
      if (!s.isWild) {
        base = s;
        break;
      }
    }
    // All wilds: pay as wild itself.
    base ??= line.first;
    if (base.isScatter) return null; // scatters don't pay on lines

    var count = 0;
    var usedWild = false;
    for (final s in line) {
      if (s.id == base.id) {
        count++;
      } else if (s.isWild) {
        count++;
        usedWild = true;
      } else {
        break;
      }
    }

    final basePay = base.payFor(count);
    if (basePay == 0) return null;

    var payout = basePay * betPerLine;
    final boosted = usedWild && !base.isWild;
    if (boosted) payout *= config.wildMultiplier;

    return LineWin(lineIndex, base, count, payout, boosted);
  }
}
