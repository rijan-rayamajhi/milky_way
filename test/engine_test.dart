import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slots/engine/slot_engine.dart';
import 'package:slots/engine/slot_symbol.dart';

void main() {
  test('5-of-a-kind on the line pays count * betPerLine', () {
    // Only the paying symbol has weight, so every cell is that symbol.
    const cfg = SlotConfig(
      symbols: [
        SlotSymbol(
            id: 'x',
            glyph: 'X',
            color: Colors.red,
            weight: 1,
            pays: {3: 2, 4: 5, 5: 10}),
        SlotSymbol(id: 'wild', glyph: 'W', color: Colors.pink, weight: 0, isWild: true),
        SlotSymbol(
            id: 'scatter', glyph: 'S', color: Colors.teal, weight: 0, isScatter: true),
      ],
      paylines: [
        [1, 1, 1, 1, 1],
      ],
      scatterPays: {},
    );
    final engine = SlotEngine(cfg, rng: Random(7));
    final o = engine.spin(2);

    expect(o.grid.length, 5);
    expect(o.grid[0].length, 3);
    expect(o.lineWins.single.count, 5);
    expect(o.totalWin, 10 * 2); // pays[5] * betPerLine
    expect(o.scatterCount, 0);
  });
}
