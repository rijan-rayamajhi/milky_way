import 'package:flutter/material.dart';
import '../models/slot_game.dart';
import '../services/sound_service.dart';
import '../theme/app_theme.dart';

/// 2.5D Arcade Slot Cabinet Card matching the console dock style.
/// Features a solid isometric extrusion ledge, dynamic press-down physics,
/// radial backlight stage, etched footer plaque, and 2.5D lock shield.
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
    final double translateY = _down ? 3.5 : 0.0;
    final double extrusionHeight = _down ? 1.5 : 5.0;

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
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              unlocked ? const Color(0xFF261245) : const Color(0xFF181024),
              unlocked ? const Color(0xFF140828) : const Color(0xFF0F0918),
              const Color(0xFF090214),
            ],
          ),
          border: Border.all(
            color: unlocked
                ? (game.glow.withValues(alpha: _down ? 0.95 : 0.65))
                : const Color(0xFF4A3C60).withValues(alpha: 0.5),
            width: 1.6,
          ),
          boxShadow: [
            // 2.5D Solid Isometric Base Ledge
            BoxShadow(
              color: const Color(0xFF060010),
              offset: Offset(0, extrusionHeight),
              blurRadius: 0,
            ),
            // Soft cast shadow below extrusion
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              offset: Offset(0, extrusionHeight + 2),
              blurRadius: 4,
            ),
            // Outer Ambient Neon Glow
            if (unlocked)
              BoxShadow(
                color: game.glow.withValues(alpha: _down ? 0.15 : 0.35),
                blurRadius: 16,
                spreadRadius: 1,
                offset: Offset(0, extrusionHeight + 1),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18.5),
          child: Stack(
            children: [
              // Radial Stage Backlight behind artwork
              if (unlocked)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.2),
                        radius: 0.65,
                        colors: [
                          game.glow.withValues(alpha: 0.35),
                          game.glow.withValues(alpha: 0.08),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                ),

              // Main Cabinet Layout
              Column(
                children: [
                  // Upper Artwork Stage
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
                      child: Center(
                        child: unlocked
                            ? Image.asset(game.asset, fit: BoxFit.contain)
                            : ColorFiltered(
                                colorFilter: const ColorFilter.matrix(_greyscale),
                                child: Image.asset(game.asset, fit: BoxFit.contain),
                              ),
                      ),
                    ),
                  ),

                  // Bottom 2.5D Gilded Console Nameplate
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF1E0E38),
                          Color(0xFF0D031A),
                        ],
                      ),
                      border: Border(
                        top: BorderSide(
                          color: (unlocked ? AppColors.gold : Colors.white24)
                              .withValues(alpha: 0.4),
                          width: 1.0,
                        ),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          game.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: unlocked ? Colors.white : Colors.white60,
                            fontWeight: FontWeight.w900,
                            fontSize: 14.5,
                            letterSpacing: 0.3,
                            shadows: const [
                              Shadow(
                                color: Colors.black,
                                offset: Offset(0, 1.5),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF090214),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: (unlocked ? game.glow : Colors.white24)
                                  .withValues(alpha: 0.3),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            game.tagline,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: unlocked ? const Color(0xFFD4C2F8) : Colors.white38,
                              fontWeight: FontWeight.w700,
                              fontSize: 9.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // 2.5D Ribbon Badge (HOT / NEW)
              if (game.badge != null && unlocked)
                Positioned(top: 8, left: 8, child: _badge(game.badge!)),

              // 2.5D Interactive Lock Shield Overlay
              if (!unlocked) _lockShield(game.unlockLevel),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String text) {
    final isHot = text == 'HOT';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isHot
              ? const [Color(0xFFFF3366), Color(0xFFB30030)]
              : const [Color(0xFF00E5FF), Color(0xFF0077B6)],
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.6),
          width: 0.8,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF090014),
            offset: Offset(0, 2),
            blurRadius: 0,
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 9.5,
          letterSpacing: 0.5,
          shadows: [
            Shadow(
              color: Colors.black54,
              offset: Offset(0, 1),
              blurRadius: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _lockShield(int unlockLevel) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.58),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 2.5D Golden Padlock Medallion
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [
                      Color(0xFFFFE082),
                      Color(0xFFFFB300),
                      Color(0xFF8D5300),
                    ],
                  ),
                  border: Border.all(color: const Color(0xFFFFF4B8), width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0xFF0A0014),
                      offset: Offset(0, 3),
                      blurRadius: 0,
                    ),
                    BoxShadow(
                      color: Color(0x66FFB300),
                      blurRadius: 8,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.lock_rounded,
                    color: Color(0xFF2C1400),
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // 2.5D Beveled Plaque
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF23143B),
                      Color(0xFF0F061F),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.8),
                    width: 1.0,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0xFF060010),
                      offset: Offset(0, 2),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Text(
                  'UNLOCK AT LV $unlockLevel',
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 0.5,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        offset: Offset(0, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
