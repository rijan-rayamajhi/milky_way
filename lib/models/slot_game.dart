import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Static metadata for each slot in the lobby. Engine config comes later;
/// this is only what the lobby grid needs to render + gate by level.
class SlotGame {
  final String id;
  final String name;
  final String tagline;
  final String asset;
  final Color glow;
  final int unlockLevel; // 1 = available from the start
  final String? badge; // "HOT" / "NEW" / null

  const SlotGame({
    required this.id,
    required this.name,
    required this.tagline,
    required this.asset,
    required this.glow,
    this.unlockLevel = 1,
    this.badge,
  });

  bool unlockedAt(int level) => level >= unlockLevel;
}

const kGames = <SlotGame>[
  SlotGame(
    id: 'cosmic_fortune',
    name: 'Cosmic Fortune',
    tagline: '25 paylines · Free Spins',
    asset: 'assets/images/games/cosmic_fortune.png',
    glow: AppColors.gold,
    unlockLevel: 1,
    badge: 'HOT',
  ),
  SlotGame(
    id: 'galaxy_gold',
    name: 'Galaxy Gold',
    tagline: 'Hold & Win · 4 Jackpots',
    asset: 'assets/images/games/galaxy_gold.png',
    glow: AppColors.gold,
    unlockLevel: 3,
    badge: 'NEW',
  ),
  SlotGame(
    id: 'starburst_nova',
    name: 'Starburst Nova',
    tagline: 'Expanding Wilds · Both Ways',
    asset: 'assets/images/games/starburst_nova.png',
    glow: AppColors.teal,
    unlockLevel: 5,
  ),
  SlotGame(
    id: 'lucky_nebula',
    name: 'Lucky Nebula',
    tagline: '243 Ways · Cascades',
    asset: 'assets/images/games/lucky_nebula.png',
    glow: AppColors.magenta,
    unlockLevel: 8,
  ),
  SlotGame(
    id: 'asteroid_blitz',
    name: 'Asteroid Blitz',
    tagline: '243 Ways · Sticky Multipliers',
    asset: 'assets/images/games/asteroid_blitz.png',
    glow: Color(0xFFFF6A3D),
    unlockLevel: 12,
  ),
];
