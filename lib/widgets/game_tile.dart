import 'package:flutter/material.dart';
import '../models/slot_game.dart';
import '../services/sound_service.dart';
import '../theme/app_theme.dart';

class GameTile extends StatefulWidget {
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
  State<GameTile> createState() => _GameTileState();
}

class _GameTileState extends State<GameTile> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final unlocked = widget.unlocked;
    final Widget art = Image.asset(game.asset, fit: BoxFit.contain);

    final double translateY = _down ? 3.0 : 0.0;
    final double extrusionHeight = _down ? 1.5 : 4.5;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        sound.tap();
        setState(() => _down = true);
      },
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, translateY, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.purple.withValues(alpha: 0.45),
              AppColors.deepPurple.withValues(alpha: 0.85),
              const Color(0xFF0F0422),
            ],
          ),
          border: Border.all(
            color: game.glow.withValues(alpha: _down ? 0.9 : 0.65),
            width: 1.5,
          ),
          boxShadow: [
            // Solid 3D isometric extrusion base
            BoxShadow(
              color: const Color(0xFF070114),
              offset: Offset(0, extrusionHeight),
              blurRadius: 0,
            ),
            // Soft neon aura
            BoxShadow(
              color: game.glow.withValues(alpha: _down ? 0.2 : 0.35),
              blurRadius: 14,
              spreadRadius: 1,
              offset: Offset(0, extrusionHeight + 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Top specular shine line
            Positioned(
              top: 1.5,
              left: 10,
              right: 10,
              height: 12,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.35),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
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
                    fontSize: 15,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        offset: Offset(0, 1.5),
                        blurRadius: 2,
                      ),
                    ],
                  ),
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
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF1E0838),
            offset: Offset(0, 1.5),
            blurRadius: 0,
          ),
        ],
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
            Text('Unlock at Lv ${widget.game.unlockLevel}',
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
