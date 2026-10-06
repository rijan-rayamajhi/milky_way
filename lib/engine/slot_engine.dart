import 'dart:math';
import 'slot_symbol.dart';

enum WinMode { lines, ways }

/// Config for one slot game. The engine is generic; each game supplies this.
class SlotConfig {
  final int reels;
  final int rows;
  final List<SlotSymbol> symbols;
  final List<List<int>> paylines; // used when mode == lines
  final WinMode mode;
  final bool paysBothWays; // ways mode: also evaluate right-to-left
  final int wildMultiplier;
  final int freeSpinScatters;
  final int freeSpinCount;
  final Map<int, int> scatterPays;

  const SlotConfig({
    required this.symbols,
    this.paylines = const [],
    this.reels = 5,
    this.rows = 3,
    this.mode = WinMode.lines,
    this.paysBothWays = false,
    this.wildMultiplier = 2,
    this.freeSpinScatters = 3,
    this.freeSpinCount = 10,
    this.scatterPays = const {3: 2, 4: 10, 5: 50},
  });

  int get waysCount => mode == WinMode.ways ? _pow(rows, reels) : 0;
  static int _pow(int b, int e) => List.filled(e, b).fold(1, (a, x) => a * x);

  SlotSymbol get wild => symbols.firstWhere((s) => s.isWild);
  SlotSymbol get scatter => symbols.firstWhere((s) => s.isScatter);
  int betMultiplier() => mode == WinMode.ways ? 25 : paylines.length;
}

class WinPart {
  final SlotSymbol symbol;
  final int count; // reels matched
  final int payout;
  final bool wildBoosted;
  const WinPart(this.symbol, this.count, this.payout, this.wildBoosted);
}

/// Result of evaluating a single grid (no RNG) — reused by cascades/respins.
class GridEval {
  final List<WinPart> wins;
  final Set<int> winCells; // reel * rows + row
  final int scatterCount;
  final int scatterPay;
  final int lineTotal; // wins + scatter
  const GridEval(this.wins, this.winCells, this.scatterCount, this.scatterPay,
      this.lineTotal);
}

class SpinOutcome {
  final List<List<SlotSymbol>> grid;
  final GridEval eval;
  final int freeSpinsAwarded;
  int get totalWin => eval.lineTotal;
  const SpinOutcome(this.grid, this.eval, this.freeSpinsAwarded);
}

class SlotEngine {
  final SlotConfig config;
  final Random rng;
  late final List<int> _cum;
  late final int _total;

  SlotEngine(this.config, {Random? rng}) : rng = rng ?? Random() {
    var acc = 0;
    _cum = [for (final s in config.symbols) acc += s.weight];
    _total = acc;
  }

  SlotSymbol pick() {
    final r = rng.nextInt(_total);
    for (var i = 0; i < _cum.length; i++) {
      if (r < _cum[i]) return config.symbols[i];
    }
    return config.symbols.last;
  }

  List<List<SlotSymbol>> randomGrid() => List.generate(
      config.reels, (_) => List.generate(config.rows, (_) => pick()));

  SpinOutcome spin(int betPerLine) {
    final grid = randomGrid();
    final eval = evaluateGrid(grid, betPerLine);
    final free = eval.scatterCount >= config.freeSpinScatters
        ? config.freeSpinCount
        : 0;
    return SpinOutcome(grid, eval, free);
  }

  // ---- Evaluation (pure, reusable) ----

  GridEval evaluateGrid(List<List<SlotSymbol>> grid, int betPerLine) {
    final wins = <WinPart>[];
    final cells = <int>{};
    var total = 0;

    if (config.mode == WinMode.lines) {
      _evalLines(grid, betPerLine, wins, cells, (p) => total += p);
    } else {
      _evalWays(grid, betPerLine, false, wins, cells, (p) => total += p);
      if (config.paysBothWays) {
        _evalWays(grid, betPerLine, true, wins, cells, (p) => total += p);
      }
    }

    var scatters = 0;
    for (var reel = 0; reel < config.reels; reel++) {
      for (var row = 0; row < config.rows; row++) {
        if (grid[reel][row].isScatter) {
          scatters++;
          cells.add(reel * config.rows + row);
        }
      }
    }
    final totalBet = betPerLine * config.betMultiplier();
    final scatterPay = (config.scatterPays[scatters] ?? 0) * totalBet;
    total += scatterPay;

    return GridEval(wins, cells, scatters, scatterPay, total);
  }

  void _evalLines(List<List<SlotSymbol>> grid, int bet, List<WinPart> wins,
      Set<int> cells, void Function(int) add) {
    for (final line in config.paylines) {
      final onLine = [
        for (var reel = 0; reel < config.reels; reel++) grid[reel][line[reel]]
      ];
      SlotSymbol? base;
      for (final s in onLine) {
        if (!s.isWild) {
          base = s;
          break;
        }
      }
      base ??= onLine.first;
      if (base.isScatter) continue;

      var count = 0;
      var usedWild = false;
      for (final s in onLine) {
        if (s.id == base.id) {
          count++;
        } else if (s.isWild) {
          count++;
          usedWild = true;
        } else {
          break;
        }
      }
      final pay = base.payFor(count);
      if (pay == 0) continue;
      var payout = pay * bet;
      final boosted = usedWild && !base.isWild;
      if (boosted) payout *= config.wildMultiplier;
      add(payout);
      wins.add(WinPart(base, count, payout, boosted));
      for (var reel = 0; reel < count; reel++) {
        cells.add(reel * config.rows + line[reel]);
      }
    }
  }

  void _evalWays(List<List<SlotSymbol>> grid, int bet, bool reversed,
      List<WinPart> wins, Set<int> cells, void Function(int) add) {
    int reelAt(int i) => reversed ? config.reels - 1 - i : i;

    for (final s in config.symbols) {
      if (s.isWild || s.isScatter || s.pays.isEmpty) continue;
      final perReelRows = <List<int>>[];
      for (var i = 0; i < config.reels; i++) {
        final reel = reelAt(i);
        final rows = <int>[
          for (var row = 0; row < config.rows; row++)
            if (grid[reel][row].id == s.id || grid[reel][row].isWild) row
        ];
        if (rows.isEmpty) break;
        perReelRows.add(rows);
      }
      final matched = perReelRows.length;
      final pay = s.payFor(matched);
      if (matched < 3 || pay == 0) continue;

      var ways = 1;
      for (final r in perReelRows) {
        ways *= r.length;
      }
      add(pay * bet * ways);
      wins.add(WinPart(s, matched, pay * bet * ways, false));
      for (var i = 0; i < matched; i++) {
        final reel = reelAt(i);
        for (final row in perReelRows[i]) {
          cells.add(reel * config.rows + row);
        }
      }
    }
  }
}

/// Total-bet levels available at [balance]. Every level is a multiple of 50,
/// and the max bet is ~[pct] of the player's balance (snapped down to a
/// multiple of 50) — so betting scales with wealth instead of a flat cap.
/// Always returns at least one level (50).
List<int> betLevelsForBalance(int balance, {double pct = 0.10}) {
  const steps = [
    50, 100, 150, 200, 250, 500, 1000, 2500, 5000, 10000, 25000, 50000,
    100000, 250000, 500000, 1000000, 2500000, 5000000,
  ];
  final maxBet = ((balance * pct) ~/ 50) * 50;
  final levels = [for (final b in steps) if (b <= maxBet) b];
  return levels.isEmpty ? const [50] : levels;
}
