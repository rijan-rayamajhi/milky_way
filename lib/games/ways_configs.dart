import 'package:flutter/material.dart';
import '../engine/slot_engine.dart';
import '../theme/app_theme.dart';
import 'ways_symbols.dart';

const _nova = 'assets/images/symbols/starburst_nova';

/// #4 Starburst Nova — 243 ways, pays both ways, expanding wilds + respin.
final starburstNovaConfig = SlotConfig(
  mode: WinMode.ways,
  paysBothWays: true,
  symbols: buildSymbols(
    highs: const [
      ('nova_red', '🔴', Color(0xFFFF5A5A), '$_nova/gem_red.png'),
      ('nova_org', '🟠', Color(0xFFFFB13D), '$_nova/gem_orange.png'),
      ('nova_grn', '🟢', Color(0xFF3DE08A), '$_nova/gem_green.png'),
      ('nova_blu', '🔵', Color(0xFF3DD7FF), '$_nova/gem_blue.png'),
      ('nova_pur', '🟣', AppColors.magenta, '$_nova/gem_purple.png'),
    ],
    wildGlyph: '🌟',
    wildColor: AppColors.gold,
    wildAsset: '$_nova/wild.png',
    scatterGlyph: '💫',
    scatterColor: AppColors.teal,
    scatterAsset: '$_nova/scatter.png',
  ),
);

/// #5 Lucky Nebula — 243 ways, cascades + multiplier ladder.
final luckyNebulaConfig = SlotConfig(
  mode: WinMode.ways,
  symbols: buildSymbols(
    highs: const [
      ('neb_horseshoe', '🧲', Color(0xFFFFC73B), null),
      ('neb_clover', '🍀', Color(0xFF3DE08A), null),
      ('neb_bell', '🔔', Color(0xFFFFB13D), null),
      ('neb_crown', '👑', AppColors.magenta, null),
      ('neb_ring', '💍', Color(0xFF3DD7FF), null),
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
      ('ab_planet', '🪐', Color(0xFFFFB13D), null),
      ('ab_moon', '🌕', Color(0xFFBFC6E0), null),
      ('ab_mars', '🔴', Color(0xFFFF5A5A), null),
      ('ab_sat', '🛰️', Color(0xFF3DD7FF), null),
      ('ab_alien', '👽', Color(0xFF3DE08A), null),
    ],
    wildGlyph: '💎',
    wildColor: AppColors.teal,
    scatterGlyph: '☄️',
    scatterColor: Color(0xFFFF6A3D),
  ),
);
