import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Lavish 2.5D In-Game HUD Toast Banner.
/// Replaces clunky OS SnackBars with an arcade-style floating announcement ribbon:
/// - Floats right below the top currency HUD
/// - 2.5D beveled metallic gold plaque with solid isometric extrusion ledge
/// - Top specular highlight glass arc and glowing backlight aura
/// - Animated 3D icon medallion (Coins, Gems, Chests, Crowns)
/// - Spring slide-down entry and auto-dismiss
class GameToast {
  static OverlayEntry? _activeEntry;
  static Timer? _dismissTimer;

  static void show(
    BuildContext context, {
    required String message,
    String? title,
    IconData? icon,
    String? assetIcon,
    Color accentColor = AppColors.gold,
  }) {
    // Dismiss any existing toast immediately
    _dismissTimer?.cancel();
    _activeEntry?.remove();
    _activeEntry = null;

    final overlay = Overlay.of(context, rootOverlay: true);

    // Auto-detect rich icon if none explicitly provided
    String? resolvedAsset = assetIcon;
    IconData? resolvedIcon = icon;
    String resolvedTitle = title ?? _detectTitle(message);

    if (resolvedAsset == null && resolvedIcon == null) {
      if (message.contains('🪙') || message.toLowerCase().contains('coin')) {
        resolvedAsset = 'assets/images/currency/coin.png';
      } else if (message.contains('💎') || message.toLowerCase().contains('gem')) {
        resolvedAsset = 'assets/images/currency/gem.png';
      } else if (message.contains('🎁') ||
          message.toLowerCase().contains('gift') ||
          message.toLowerCase().contains('pack') ||
          message.toLowerCase().contains('explorer')) {
        resolvedAsset = 'assets/images/engagement/reward_chest.png';
      } else if (message.contains('👑') ||
          message.toLowerCase().contains('jackpot')) {
        resolvedIcon = Icons.military_tech_rounded;
      } else {
        resolvedIcon = Icons.auto_awesome_rounded;
      }
    }

    // Clean emojis from the message for the body text if desired
    final cleanMessage = message.replaceAll(RegExp(r'[🪙💎🎁👑✨🌟]'), '').trim();

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _GameToastWidget(
        title: resolvedTitle,
        message: cleanMessage.isNotEmpty ? cleanMessage : message,
        assetIcon: resolvedAsset,
        icon: resolvedIcon,
        accentColor: accentColor,
        onDismiss: () {
          if (_activeEntry == entry) {
            _activeEntry?.remove();
            _activeEntry = null;
          }
        },
      ),
    );

    _activeEntry = entry;
    overlay.insert(entry);
  }

  static String _detectTitle(String msg) {
    final lower = msg.toLowerCase();
    if (lower.contains('jackpot')) return 'MEGA JACKPOT!';
    if (lower.contains('explorer')) return 'EXPLORER KIT';
    if (lower.contains('coin')) return 'COINS DELIVERED';
    if (lower.contains('gem')) return 'GEMS UNLOCKED';
    if (lower.contains('gift')) return 'COSMIC REWARD';
    if (lower.contains('level')) return 'LEVEL UP BONUS';
    return 'COSMIC REWARD';
  }
}

class _GameToastWidget extends StatefulWidget {
  final String title;
  final String message;
  final String? assetIcon;
  final IconData? icon;
  final Color accentColor;
  final VoidCallback onDismiss;

  const _GameToastWidget({
    required this.title,
    required this.message,
    this.assetIcon,
    this.icon,
    required this.accentColor,
    required this.onDismiss,
  });

  @override
  State<_GameToastWidget> createState() => _GameToastWidgetState();
}

class _GameToastWidgetState extends State<_GameToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _slideAnim;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _slideAnim = Tween<double>(begin: -60.0, end: 0.0).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeOutBack),
    );

    _fadeAnim = CurvedAnimation(parent: _anim, curve: Curves.easeOut);

    _scaleAnim = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeOutBack),
    );

    _anim.forward();

    // Auto-dismiss after 2.6 seconds
    _timer = Timer(const Duration(milliseconds: 2600), () => _dismiss());
  }

  void _dismiss() {
    if (!mounted) return;
    _timer?.cancel();
    _anim.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 62, // Floats cleanly right beneath the CurrencyBar
      left: 16,
      right: 16,
      child: Material(
        type: MaterialType.transparency,
        child: AnimatedBuilder(
          animation: _anim,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _slideAnim.value),
              child: Transform.scale(
                scale: _scaleAnim.value,
                child: Opacity(
                  opacity: _fadeAnim.value.clamp(0.0, 1.0),
                  child: child,
                ),
              ),
            );
          },
          child: GestureDetector(
            onTap: _dismiss,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                // Deep cosmic obsidian gradient
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF331464),
                    Color(0xFF190835),
                    Color(0xFF0B031B),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: widget.accentColor, width: 1.5),
                boxShadow: [
                  // Solid 3D isometric extrusion ledge
                  const BoxShadow(
                    color: Color(0xFF05010E),
                    offset: Offset(0, 4),
                    blurRadius: 0,
                  ),
                  // Outer radiant aura
                  BoxShadow(
                    color: widget.accentColor.withValues(alpha: 0.35),
                    blurRadius: 18,
                    spreadRadius: 2,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Top Specular Highlight Rim Arc
                  Positioned(
                    top: 1,
                    left: 6,
                    right: 6,
                    height: 12,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.55),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),

                  Row(
                    children: [
                      // 2.5D Icon Medallion
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              widget.accentColor.withValues(alpha: 0.3),
                              AppColors.navy,
                            ],
                          ),
                          border: Border.all(
                            color: widget.accentColor,
                            width: 1.4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF04010A),
                              offset: const Offset(0, 2.5),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Center(
                          child: widget.assetIcon != null
                              ? Image.asset(widget.assetIcon!,
                                  width: 28, height: 28)
                              : Icon(widget.icon ?? Icons.auto_awesome,
                                  color: widget.accentColor, size: 24),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Text Info
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: widget.accentColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 0.6,
                                shadows: const [
                                  Shadow(
                                    color: Colors.black,
                                    offset: Offset(0, 1),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.message,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                shadows: [
                                  Shadow(
                                    color: Colors.black,
                                    offset: Offset(0, 1),
                                    blurRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Close icon or sparkle
                      Icon(
                        Icons.close_rounded,
                        color: AppColors.textDim.withValues(alpha: 0.6),
                        size: 18,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
