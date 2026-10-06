import 'package:flutter/material.dart';
import '../engine/slot_symbol.dart';

const _roy = 'assets/images/symbols/royals';

/// A themed high symbol: (id, glyph, color, assetPath?).
typedef High = (String, String, Color, String?);

/// Builds a standard 12-symbol set: 5 themed highs + A/K/Q/J/10 lows +
/// a wild and a scatter. Keeps pays/weights consistent across games so the
/// shared engine behaves predictably; only the glyphs/theme change.
List<SlotSymbol> buildSymbols({
  required List<High> highs, // exactly 5, strongest first
  required String wildGlyph,
  required Color wildColor,
  required String scatterGlyph,
  required Color scatterColor,
  String? wildAsset,
  String? scatterAsset,
  double payScale = 1.0, // multiplies every payout to tune RTP
}) {
  assert(highs.length == 5);
  Map<int, int> s(Map<int, int> p) =>
      {for (final e in p.entries) e.key: (e.value * payScale).round().clamp(1, 1 << 30)};
  final highPays = <Map<int, int>>[
    s({3: 8, 4: 20, 5: 50}),
    s({3: 6, 4: 15, 5: 40}),
    s({3: 5, 4: 12, 5: 30}),
    s({3: 4, 4: 10, 5: 25}),
    s({3: 3, 4: 8, 5: 20}),
  ];
  const highWeights = [5, 6, 8, 10, 12];

  return [
    for (var i = 0; i < 5; i++)
      SlotSymbol(
        id: highs[i].$1,
        glyph: highs[i].$2,
        color: highs[i].$3,
        asset: highs[i].$4,
        weight: highWeights[i],
        pays: highPays[i],
      ),
    SlotSymbol(
        id: 'A', glyph: 'A', asset: '$_roy/a.png', color: const Color(0xFFFF7BD5), weight: 14, pays: s({3: 2, 4: 5, 5: 15})),
    SlotSymbol(
        id: 'K', glyph: 'K', asset: '$_roy/k.png', color: const Color(0xFF7BC4FF), weight: 16, pays: s({3: 2, 4: 5, 5: 12})),
    SlotSymbol(
        id: 'Q', glyph: 'Q', asset: '$_roy/q.png', color: const Color(0xFF8CF0C0), weight: 16, pays: s({3: 1, 4: 4, 5: 10})),
    SlotSymbol(
        id: 'J', glyph: 'J', asset: '$_roy/j.png', color: const Color(0xFFC9B8FF), weight: 20, pays: s({3: 1, 4: 3, 5: 8})),
    SlotSymbol(
        id: '10', glyph: '10', asset: '$_roy/ten.png', color: const Color(0xFFBFC6E0), weight: 20, pays: s({3: 1, 4: 3, 5: 8})),
    SlotSymbol(
        id: 'wild',
        glyph: wildGlyph,
        asset: wildAsset,
        color: wildColor,
        weight: 3,
        isWild: true,
        pays: s({3: 10, 4: 30, 5: 100})),
    SlotSymbol(
        id: 'scatter',
        glyph: scatterGlyph,
        asset: scatterAsset,
        color: scatterColor,
        weight: 3,
        isScatter: true),
  ];
}
