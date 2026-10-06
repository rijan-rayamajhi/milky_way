import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:slots/engine/slot_engine.dart';
import 'package:slots/games/cosmic_fortune_config.dart';
import 'package:slots/games/ways_configs.dart';

/// Base-game Monte Carlo over the real SlotEngine. Measures per-spin hit
/// frequency (chance a spin returns > 0), RTP, and free-spin trigger rate.
/// Note: special features (cascades, respins, expanding/sticky wilds, the
/// free-spin rounds themselves, Galaxy Gold Hold & Win) live in the screens,
/// not the base config — so these are BASE-GAME figures.
void main() {
  const spins = 3000000;
  const betPerLine = 1;

  void sim(String name, SlotConfig cfg) {
    final engine = SlotEngine(cfg, rng: Random(12345));
    final wager = betPerLine * cfg.betMultiplier();
    var hits = 0;
    var totalWon = 0;
    var totalWager = 0;
    var freeTriggers = 0;
    for (var i = 0; i < spins; i++) {
      final o = engine.spin(betPerLine);
      totalWager += wager;
      if (o.totalWin > 0) {
        hits++;
        totalWon += o.totalWin;
      }
      if (o.freeSpinsAwarded > 0) freeTriggers++;
    }
    final hitPct = 100 * hits / spins;
    final rtp = 100 * totalWon / totalWager;
    final oneIn = spins / hits;
    final freePct = 100 * freeTriggers / spins;
    // ignore: avoid_print
    print('$name\n'
        '  win chance/spin : ${hitPct.toStringAsFixed(2)}%  (≈ 1 in ${oneIn.toStringAsFixed(1)})\n'
        '  base-game RTP   : ${rtp.toStringAsFixed(1)}%\n'
        '  free-spin trig  : ${freePct.toStringAsFixed(3)}%  (≈ 1 in ${(spins / freeTriggers).toStringAsFixed(0)})\n');
  }

  test('win probabilities', () {
    // ignore: avoid_print
    print('\n=== BASE-GAME WIN PROBABILITY ($spins spins each) ===\n');
    sim('Cosmic Fortune (25 lines)', cosmicFortuneConfig);
    sim('Starburst Nova (243 ways, both)', starburstNovaConfig);
    sim('Lucky Nebula (243 ways)', luckyNebulaConfig);
    sim('Asteroid Blitz (243 ways)', asteroidBlitzConfig);
  });
}
