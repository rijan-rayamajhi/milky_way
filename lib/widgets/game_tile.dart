import 'package:flutter/material.dart';
import '../models/slot_game.dart';
import '../theme/app_theme.dart';

class GameTile extends StatelessWidget {
  final SlotGame game;
  final bool unlocked;
  final VoidCallback onTap;

  const GameTile({
    super.key,
    required this.game,
    required this.unlocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Widget art = Image.asset(game.asset, fit: BoxFit.contain);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.purple.withValues(alpha: 0.35),
              AppColors.deepPurple.withValues(alpha: 0.75),
            ],
          ),
          border: Border.all(color: game.glow.withValues(alpha: 0.7), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: game.glow.withValues(alpha: 0.35),
                blurRadius: 14,
                spreadRadius: 1),
          ],
        ),
        child: Stack(
          children: [
            Column(
              children: [
                const SizedBox(height: 10),
                Expanded(
                  child: unlocked
                      ? art
                      : ColorFiltered(
                          colorFilter: const ColorFilter.matrix(_greyscale),
                          child: art,
                        ),
                ),
                const SizedBox(height: 4),
                Text(
                  game.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    game.tagline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textDim, fontSize: 11),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
            if (game.badge != null && unlocked)
              Positioned(top: 8, left: 8, child: _badge(game.badge!)),
            if (!unlocked) _lockOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text) {
    final isHot = text == 'HOT';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isHot ? AppColors.magenta : AppColors.teal,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10)),
    );
  }

  Widget _lockOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, color: AppColors.gold, size: 32),
            const SizedBox(height: 4),
            Text('Unlock at Lv ${game.unlockLevel}',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12)),
          ],
        ),
      ),
    );
  }

  // Desaturation matrix for locked tiles.
  static const _greyscale = <double>[
    0.33, 0.33, 0.33, 0, 0, //
    0.33, 0.33, 0.33, 0, 0, //
    0.33, 0.33, 0.33, 0, 0, //
    0, 0, 0, 1, 0, //
  ];
}
