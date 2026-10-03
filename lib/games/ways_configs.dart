import 'package:flutter/material.dart';
import '../engine/slot_engine.dart';
import '../theme/app_theme.dart';
import 'ways_symbols.dart';

/// #4 Starburst Nova — 243 ways, pays both ways, expanding wilds + respin.
final starburstNovaConfig = SlotConfig(
  mode: WinMode.ways,
  paysBothWays: true,
  symbols: buildSymbols(
    highs: const [
      ('nova_red', '🔴', Color(0xFFFF5A5A)),
      ('nova_org', '🟠', Color(0xFFFFB13D)),
      ('nova_grn', '🟢', Color(0xFF3DE08A)),
      ('nova_blu', '🔵', Color(0xFF3DD7FF)),
      ('nova_pur', '🟣', AppColors.magenta),
    ],
    wildGlyph: '🌟',
    wildColor: AppColors.gold,
    scatterGlyph: '💫',
    scatterColor: AppColors.teal,
  ),
);

/// #5 Lucky Nebula — 243 ways, cascades + multiplier ladder.
final luckyNebulaConfig = SlotConfig(
  mode: WinMode.ways,
  symbols: buildSymbols(
    highs: const [
      ('neb_horseshoe', '🧲', Color(0xFFFFC73B)),
      ('neb_clover', '🍀', Color(0xFF3DE08A)),
      ('neb_bell', '🔔', Color(0xFFFFB13D)),
      ('neb_crown', '👑', AppColors.magenta),
      ('neb_ring', '💍', Color(0xFF3DD7FF)),
    ],
    wildGlyph: '🌀',
    wildColor: AppColors.magenta,
    scatterGlyph: '🎰',
    scatterColor: AppColors.teal,
  ),
);

/// #6 Asteroid Blitz — 243 ways, sticky multiplier wilds + free spins.
final asteroidBlitzConfig = SlotConfig(
  mode: WinMode.ways,
  symbols: buildSymbols(
    highs: const [
      ('ab_planet', '🪐', Color(0xFFFFB13D)),
      ('ab_moon', '🌕', Color(0xFFBFC6E0)),
      ('ab_mars', '🔴', Color(0xFFFF5A5A)),
      ('ab_sat', '🛰️', Color(0xFF3DD7FF)),
      ('ab_alien', '👽', Color(0xFF3DE08A)),
    ],
    wildGlyph: '💎',
    wildColor: AppColors.teal,
    scatterGlyph: '☄️',
    scatterColor: Color(0xFFFF6A3D),
  ),
);
