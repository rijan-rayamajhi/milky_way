import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/sound_service.dart';
import '../theme/app_theme.dart';

/// A lavish 2.5D Game HUD Bottom Navigation Bar.
/// Features:
/// - Sculpted metallic gold console dock with specular light rail and corner studs
/// - Physical 3D chunky tactile buttons with authentic mechanical press-down physics
/// - Elevated active tab on a 2.5D golden pedestal with radiant cosmic back-glow
/// - 3D faceted ruby jewel badge with specular shine and breathing pulse
/// - 2.5D emerald/gold claimable beacon for daily rewards
/// - Sound effects and haptics on every interaction
class GameBottomNavBar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final int unreadMailCount;
  final bool canClaimDaily;

  const GameBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
    this.unreadMailCount = 0,
    this.canClaimDaily = false,
  });

  @override
  State<GameBottomNavBar> createState() => _GameBottomNavBarState();
}

class _GameBottomNavBarState extends State<GameBottomNavBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final tabs = [
      _TabDef(
        icon: Icons.home_rounded,
        label: 'LOBBY',
        altIcon: Icons.home_rounded,
      ),
      _TabDef(
        icon: Icons.storefront_rounded,
        label: 'STORE',
        altIcon: Icons.storefront_rounded,
      ),
      _TabDef(
        icon: Icons.mark_email_unread_rounded,
        label: 'MAILBOX',
        altIcon: Icons.mail_rounded,
        badgeCount: widget.unreadMailCount,
      ),
      _TabDef(
        icon: Icons.stars_rounded,
        label: 'DAILY',
        altIcon: Icons.calendar_month_rounded,
        hasDot: widget.canClaimDaily,
      ),
      _TabDef(
        icon: Icons.person_rounded,
        label: 'PROFILE',
        altIcon: Icons.person_rounded,
      ),
    ];

    return Container(
      // Allow elevated buttons to overflow above the bar naturally
      clipBehavior: Clip.none,
      decoration: BoxDecoration(
        boxShadow: [
          // Ambient cosmic outer glow projecting upwards into the screen
          BoxShadow(
            color: AppColors.purple.withValues(alpha: 0.35),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, -6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.8),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // Glassmorphic & metallic dock chassis
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: EdgeInsets.only(
                  bottom: math.max(bottomPadding, 10),
                  top: 10,
                  left: 8,
                  right: 8,
                ),
                decoration: BoxDecoration(
                  // Multi-layered metallic cosmic gradient
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF26104F), // Deep cosmic purple
                      Color(0xFF13062B), // Obsidian dark
                      Color(0xFF080216), // Solid void base
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(22),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: AppColors.gold.withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                  ),
                ),
                child: CustomPaint(
                  painter: _ConsoleDockPainter(),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (int i = 0; i < tabs.length; i++)
                        Expanded(
                          child: _TactileGameButton(
                            tab: tabs[i],
                            index: i,
                            isSelected: widget.selectedIndex == i,
                            pulseAnimation: _pulseController,
                            onTap: () => widget.onTabSelected(i),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Metallic Specular Gold Highlight Rim across the top edge
          Positioned(
            top: 0,
            left: 20,
            right: 20,
            height: 2,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: const LinearGradient(
                  colors: [
                    Colors.transparent,
                    Color(0xFFFFEFA8),
                    Color(0xFFFFD700),
                    Color(0xFFFFF6C8),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.25, 0.5, 0.75, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabDef {
  final IconData icon;
  final IconData altIcon;
  final String label;
  final int badgeCount;
  final bool hasDot;

  const _TabDef({
    required this.icon,
    required this.altIcon,
    required this.label,
    this.badgeCount = 0,
    this.hasDot = false,
  });
}

/// A tactile 2.5D push-button with physical mechanical depth, extrusion ledge,
/// and active pedestal elevation.
class _TactileGameButton extends StatefulWidget {
  final _TabDef tab;
  final int index;
  final bool isSelected;
  final Animation<double> pulseAnimation;
  final VoidCallback onTap;

  const _TactileGameButton({
    required this.tab,
    required this.index,
    required this.isSelected,
    required this.pulseAnimation,
    required this.onTap,
  });

  @override
  State<_TactileGameButton> createState() => _TactileGameButtonState();
}

class _TactileGameButtonState extends State<_TactileGameButton> {
  bool _isDown = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.isSelected;
    final tab = widget.tab;

    // In 2.5D UI:
    // - Active button floats UP by -10px
    // - Pressing down translates DOWN by +3px
    final double translateY = (active ? -10.0 : 0.0) + (_isDown ? 3.0 : 0.0);
    final double extrusionHeight = _isDown ? 1.0 : (active ? 4.5 : 3.0);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        sound.tap();
        setState(() => _isDown = true);
      },
      onTapUp: (_) {
        setState(() => _isDown = false);
        widget.onTap();
      },
      onTapCancel: () {
        setState(() => _isDown = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        transform: Matrix4.translationValues(0, translateY, 0),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // Active aura halo under the button
                  if (active)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.gold.withValues(alpha: 0.45),
                              blurRadius: 18,
                              spreadRadius: 3,
                            ),
                            BoxShadow(
                              color: AppColors.teal.withValues(alpha: 0.3),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 2.5D Button Body
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    height: active ? 48 : 42,
                    width: active ? 54 : 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(active ? 15 : 12),
                      gradient: active
                          ? const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0xFFFFF9C4), // Gleaming top white-gold
                                Color(0xFFFFD54F), // Radiant gold
                                Color(0xFFFFB300), // Rich amber
                                Color(0xFFE65100), // Deep 3D base bevel
                              ],
                              stops: [0.0, 0.35, 0.75, 1.0],
                            )
                          : LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                const Color(0xFF321A63).withValues(alpha: 0.9),
                                const Color(0xFF1B0B3B).withValues(alpha: 0.95),
                                const Color(0xFF0F0424),
                              ],
                            ),
                      border: Border.all(
                        color: active
                            ? const Color(0xFFFFF3B0)
                            : const Color(0xFF734FA6).withValues(alpha: 0.5),
                        width: active ? 1.8 : 1.2,
                      ),
                      boxShadow: [
                        // 3D Isometric Extrusion Ledge (Zero blur creates solid physical thickness!)
                        BoxShadow(
                          color: active
                              ? const Color(0xFF632800) // Dark amber shadow ledge
                              : const Color(0xFF06010F), // Dark obsidian ledge
                          offset: Offset(0, extrusionHeight),
                          blurRadius: 0,
                        ),
                        // Soft cast shadow below the 3D block
                        BoxShadow(
                          color: Colors.black.withValues(alpha: active ? 0.5 : 0.35),
                          offset: Offset(0, extrusionHeight + 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Top Specular Highlight Arc
                        Positioned(
                          top: 1.5,
                          left: 4,
                          right: 4,
                          height: active ? 14 : 10,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withValues(
                                    alpha: active ? 0.65 : 0.25,
                                  ),
                                  Colors.white.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Icon with game depth
                        Icon(
                          active ? tab.icon : tab.altIcon,
                          size: active ? 26 : 22,
                          color: active
                              ? const Color(0xFF1A0A3D) // Contrast royal navy on gold
                              : AppColors.textDim,
                          shadows: active
                              ? [
                                  // Bevel embossed highlight on active icon
                                  Shadow(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    offset: const Offset(0, 1),
                                    blurRadius: 1,
                                  ),
                                ]
                              : [
                                  // Drop shadow on inactive icon
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.8),
                                    offset: const Offset(0, 1.5),
                                    blurRadius: 2,
                                  ),
                                ],
                        ),
                      ],
                    ),
                  ),

                  // 3D Ruby Gem Badge (Mailbox)
                  if (tab.badgeCount > 0)
                    Positioned(
                      top: active ? -4 : -3,
                      right: active ? -6 : -4,
                      child: _JewelBadge(
                        count: tab.badgeCount,
                        pulse: widget.pulseAnimation,
                      ),
                    ),

                  // 2.5D Daily Beacon Star (Daily Reward)
                  if (tab.hasDot)
                    Positioned(
                      top: active ? -4 : -3,
                      right: active ? -4 : -2,
                      child: _DailyBeacon(pulse: widget.pulseAnimation),
                    ),
                ],
              ),
              const SizedBox(height: 4),

              // 2.5D Embossed Label
              Text(
                tab.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? AppColors.gold : AppColors.textDim,
                  fontSize: 10,
                  fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                  letterSpacing: 0.5,
                  shadows: [
                    Shadow(
                      color: active
                          ? AppColors.gold.withValues(alpha: 0.6)
                          : Colors.black.withValues(alpha: 0.9),
                      offset: const Offset(0, 1),
                      blurRadius: active ? 6 : 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A 3D Faceted Ruby Jewel Notification Badge
class _JewelBadge extends StatelessWidget {
  final int count;
  final Animation<double> pulse;

  const _JewelBadge({required this.count, required this.pulse});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) {
        final scale = 1.0 + (pulse.value * 0.12);
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFF5277), // Bright ruby specular
              Color(0xFFE91E63), // Rich ruby body
              Color(0xFF880E4F), // Dark faceted ruby base
            ],
          ),
          border: Border.all(color: AppColors.gold, width: 1.4),
          boxShadow: [
            // Solid 3D extrusion bottom edge
            const BoxShadow(
              color: Color(0xFF4A0019),
              offset: Offset(0, 2),
              blurRadius: 0,
            ),
            // Glowing ruby aura
            BoxShadow(
              color: const Color(0xFFFF1744).withValues(alpha: 0.6),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
        child: Center(
          child: Text(
            '$count',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(
                  color: Colors.black,
                  offset: Offset(0, 1),
                  blurRadius: 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A 2.5D Pulsing Emerald / Celestial Beacon for claimable rewards
class _DailyBeacon extends StatelessWidget {
  final Animation<double> pulse;

  const _DailyBeacon({required this.pulse});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) {
        final scale = 0.95 + (pulse.value * 0.22);
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            colors: [
              Color(0xFFE040FB), // Magenta flare
              Color(0xFFAA00FF), // Deep purple-magenta
              Color(0xFF4A148C), // Shadow edge
            ],
            stops: [0.2, 0.7, 1.0],
          ),
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [
            // Solid 3D edge
            const BoxShadow(
              color: Color(0xFF2E0854),
              offset: Offset(0, 1.5),
              blurRadius: 0,
            ),
            // Neon flare glow
            BoxShadow(
              color: AppColors.magenta.withValues(alpha: 0.8),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter for the dock chassis: adds decorative golden diamond rivets
/// on the outer wings and subtle beveled divider grooves.
class _ConsoleDockPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final goldPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFFFFF9C4),
          Color(0xFFFFD54F),
          Color(0xFFB8860B),
          Color(0xFFFFD54F),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 10));

    final shadowPaint = Paint()..color = const Color(0xFF070212);

    // Left and right decorative 2.5D diamond rivets/studs
    _drawDiamondStud(canvas, const Offset(12, 6), 4.5, goldPaint, shadowPaint);
    _drawDiamondStud(
        canvas, Offset(size.width - 12, 6), 4.5, goldPaint, shadowPaint);
  }

  void _drawDiamondStud(Canvas canvas, Offset center, double radius,
      Paint goldPaint, Paint shadowPaint) {
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx + radius, center.dy)
      ..lineTo(center.dx, center.dy + radius)
      ..lineTo(center.dx - radius, center.dy)
      ..close();

    // 3D Shadow underneath stud
    final shadowPath = Path()
      ..moveTo(center.dx, center.dy - radius + 1.5)
      ..lineTo(center.dx + radius, center.dy + 1.5)
      ..lineTo(center.dx, center.dy + radius + 1.5)
      ..lineTo(center.dx - radius, center.dy + 1.5)
      ..close();

    canvas.drawPath(shadowPath, shadowPaint);
    canvas.drawPath(path, goldPaint);

    // Center specular glint
    final glintPaint = Paint()..color = Colors.white.withValues(alpha: 0.85);
    canvas.drawCircle(Offset(center.dx - 0.8, center.dy - 0.8), 1.0, glintPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
