import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slots/engine/slot_engine.dart';
import 'package:slots/engine/slot_symbol.dart';

SlotSymbol _sym(String id, int w, {Map<int, int> pays = const {}}) =>
    SlotSymbol(id: id, glyph: id, color: Colors.red, weight: w, pays: pays);

void main() {
  test('lines mode: 5-of-a-kind pays count * betPerLine', () {
    final cfg = SlotConfig(
      symbols: [
        _sym('x', 1, pays: {3: 2, 4: 5, 5: 10}),
        SlotSymbol(id: 'w', glyph: 'W', color: Colors.pink, weight: 0, isWild: true),
        SlotSymbol(id: 's', glyph: 'S', color: Colors.teal, weight: 0, isScatter: true),
      ],
      paylines: const [
        [1, 1, 1, 1, 1],
      ],
      scatterPays: const {},
    );
    final o = SlotEngine(cfg, rng: Random(7)).spin(2);
    expect(o.eval.wins.single.count, 5);
    expect(o.totalWin, 10 * 2);
  });

  test('ways mode: full grid of one symbol = rows^reels ways', () {
    final cfg = SlotConfig(
      mode: WinMode.ways,
      symbols: [
        _sym('x', 1, pays: {3: 1, 4: 2, 5: 5}),
        SlotSymbol(id: 'w', glyph: 'W', color: Colors.pink, weight: 0, isWild: true),
        SlotSymbol(id: 's', glyph: 'S', color: Colors.teal, weight: 0, isScatter: true),
      ],
      scatterPays: const {},
    );
    // Every cell is 'x' → ways = 3^5 = 243, pay[5]=5, bet=2.
    final o = SlotEngine(cfg, rng: Random(1)).spin(2);
    expect(o.eval.wins.single.count, 5);
    expect(o.totalWin, 5 * 2 * 243);
  });
}
