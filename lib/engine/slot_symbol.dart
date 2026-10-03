import 'package:flutter/material.dart';

/// A reel symbol. [pays] maps a match-count (3/4/5) to a payout expressed
/// as a multiple of the per-line bet.
class SlotSymbol {
  final String id;
  final String glyph; // emoji / short text, swappable for art later
  final Color color;
  final int weight; // relative frequency on the reels
  final bool isWild;
  final bool isScatter;
  final Map<int, int> pays;

  const SlotSymbol({
    required this.id,
    required this.glyph,
    required this.color,
    required this.weight,
    this.isWild = false,
    this.isScatter = false,
    this.pays = const {},
  });

  int payFor(int count) => pays[count] ?? 0;
}
