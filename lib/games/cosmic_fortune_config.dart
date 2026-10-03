import 'package:flutter/material.dart';
import '../engine/slot_engine.dart';
import '../engine/slot_symbol.dart';
import '../theme/app_theme.dart';

/// Cosmic Fortune — 5x3, 25 paylines, wild (x2) + scatter free spins.
/// Symbol glyphs are emoji/text placeholders; swap for art later.
const _cf = 'assets/images/symbols/cosmic_fortune';
const _roy = 'assets/images/symbols/royals';

const _symbols = <SlotSymbol>[
  SlotSymbol(
      id: 'rocket',
      glyph: '🚀',
      asset: '$_cf/rocket.png',
      color: Color(0xFFFF5A5A),
      weight: 5,
      pays: {3: 8, 4: 20, 5: 50}),
  SlotSymbol(
      id: 'astronaut',
      glyph: '👨‍🚀',
      asset: '$_cf/astronaut.png',
      color: Color(0xFF9B6CFF),
      weight: 6,
      pays: {3: 6, 4: 15, 5: 40}),
  SlotSymbol(
      id: 'ufo',
      glyph: '🛸',
      asset: '$_cf/ufo.png',
      color: Color(0xFF3DD7FF),
      weight: 8,
      pays: {3: 5, 4: 12, 5: 30}),
  SlotSymbol(
      id: 'planet',
      glyph: '🪐',
      asset: '$_cf/planet.png',
      color: Color(0xFFFFB13D),
      weight: 10,
      pays: {3: 4, 4: 10, 5: 25}),
  SlotSymbol(
      id: 'star',
      glyph: '⭐',
      asset: '$_cf/star.png',
      color: AppColors.gold,
      weight: 12,
      pays: {3: 3, 4: 8, 5: 20}),
  SlotSymbol(
      id: 'A',
      glyph: 'A',
      asset: '$_roy/a.png',
      color: Color(0xFFFF7BD5),
      weight: 14,
      pays: {3: 2, 4: 5, 5: 15}),
  SlotSymbol(
      id: 'K',
      glyph: 'K',
      asset: '$_roy/k.png',
      color: Color(0xFF7BC4FF),
      weight: 16,
      pays: {3: 2, 4: 5, 5: 12}),
  SlotSymbol(
      id: 'Q',
      glyph: 'Q',
      asset: '$_roy/q.png',
      color: Color(0xFF8CF0C0),
      weight: 16,
      pays: {3: 1, 4: 4, 5: 10}),
  SlotSymbol(
      id: 'J',
      glyph: 'J',
      asset: '$_roy/j.png',
      color: Color(0xFFC9B8FF),
      weight: 20,
      pays: {3: 1, 4: 3, 5: 8}),
  SlotSymbol(
      id: '10',
      glyph: '10',
      asset: '$_roy/ten.png',
      color: Color(0xFFBFC6E0),
      weight: 20,
      pays: {3: 1, 4: 3, 5: 8}),
  SlotSymbol(
      id: 'wild',
      glyph: '🕳️',
      asset: '$_cf/wild.png',
      color: AppColors.magenta,
      weight: 3,
      isWild: true,
      pays: {3: 10, 4: 30, 5: 100}),
  SlotSymbol(
      id: 'scatter',
      glyph: '🌌',
      asset: '$_cf/scatter.png',
      color: AppColors.teal,
      weight: 3,
      isScatter: true),
];

/// 25 fixed paylines over a 5x3 grid (row index per reel).
const _paylines = <List<int>>[
  [1, 1, 1, 1, 1], // 1 middle
  [0, 0, 0, 0, 0], // 2 top
  [2, 2, 2, 2, 2], // 3 bottom
  [0, 1, 2, 1, 0], // 4 V
  [2, 1, 0, 1, 2], // 5 ^
  [0, 0, 1, 2, 2],
  [2, 2, 1, 0, 0],
  [1, 0, 0, 0, 1],
  [1, 2, 2, 2, 1],
  [0, 1, 1, 1, 0],
  [2, 1, 1, 1, 2],
  [1, 0, 1, 2, 1],
  [1, 2, 1, 0, 1],
  [0, 1, 0, 1, 0],
  [2, 1, 2, 1, 2],
  [1, 1, 0, 1, 1],
  [1, 1, 2, 1, 1],
  [0, 0, 2, 0, 0],
  [2, 2, 0, 2, 2],
  [0, 2, 0, 2, 0],
  [2, 0, 2, 0, 2],
  [1, 0, 2, 0, 1],
  [1, 2, 0, 2, 1],
  [0, 2, 2, 2, 0],
  [2, 0, 0, 0, 2],
];

const cosmicFortuneConfig = SlotConfig(
  symbols: _symbols,
  paylines: _paylines,
  wildMultiplier: 2,
  freeSpinScatters: 3,
  freeSpinCount: 10,
  scatterPays: {3: 2, 4: 10, 5: 50},
);
