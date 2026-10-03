import 'package:flutter/material.dart';
import '../services/sound_service.dart';
import '../theme/app_theme.dart';

/// Lavish 2.5D Game Push-Button.
/// Features:
/// - Solid 3D isometric extrusion ledge (zero blur creates genuine physical block depth)
/// - Physical mechanical button depression physics on tap down (translates down + squishes)
/// - Top specular highlight glass arc for a rich glossy arcade console finish
/// - Stamped embossed text with high contrast and rim lighting
/// - Multi-tone cosmic gradients with companion extrusion shadows (Gold, Teal, Magenta, Deep Void)
/// - Instant responsive audio (sound.tap()) and haptics on tap-down
class CosmicButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final double height;
  final double? width;
  final double? fontSize;
  final EdgeInsetsGeometry? padding;
  final Color? textColor;
  final Color? extrusionColor;

  const CosmicButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.gradient,
    this.height = 54,
    this.width,
    this.fontSize,
    this.padding,
    this.textColor,
    this.extrusionColor,
  });

  @override
  State<CosmicButton> createState() => _CosmicButtonState();
}

class _CosmicButtonState extends State<CosmicButton> {
  bool _isDown = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final isCompact = widget.height < 45;

    // Determine style theme based on gradient colors
    final theme = _resolveTheme(widget.gradient);

    // 2.5D button physics:
    // When pressed down, translate DOWN by 2.5-3px and compress extrusion height
    final double translateY = _isDown ? (isCompact ? 2.0 : 3.0) : 0.0;
    final double extrusionHeight =
        _isDown ? 1.0 : (isCompact ? 3.2 : 4.5);

    final double effectiveFontSize =
        widget.fontSize ?? (isCompact ? 12.5 : 16.0);
    final EdgeInsetsGeometry effectivePadding = widget.padding ??
        EdgeInsets.symmetric(horizontal: isCompact ? 12 : 20);

    final double borderRadius = isCompact ? 12.0 : 16.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled
          ? (_) {
              sound.tap();
              setState(() => _isDown = true);
            }
          : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _isDown = false);
              widget.onTap!();
            }
          : null,
      onTapCancel: enabled ? () => setState(() => _isDown = false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, translateY, 0),
        child: Opacity(
          opacity: enabled ? 1.0 : 0.5,
          child: Container(
            height: widget.height,
            width: widget.width,
            padding: effectivePadding,
            decoration: BoxDecoration(
              gradient: theme.faceGradient,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: theme.rimBorderColor,
                width: isCompact ? 1.3 : 1.6,
              ),
              boxShadow: [
                // 1. Solid 3D Isometric Extrusion Ledge (Zero blur gives physical block depth!)
                BoxShadow(
                  color: widget.extrusionColor ?? theme.extrusionColor,
                  offset: Offset(0, extrusionHeight),
                  blurRadius: 0,
                ),
                // 2. Ambient cast shadow on the surface beneath
                BoxShadow(
                  color: Colors.black.withValues(alpha: enabled ? 0.45 : 0.2),
                  offset: Offset(0, extrusionHeight + 2),
                  blurRadius: 4,
                ),
                // 3. Radiant cosmic backlight glow
                if (enabled && !_isDown)
                  BoxShadow(
                    color: theme.glowColor.withValues(alpha: 0.35),
                    blurRadius: isCompact ? 10 : 16,
                    spreadRadius: 1,
                  ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Top Specular Highlight Arc (Arcade Glass Sheen)
                Positioned(
                  top: 1.5,
                  left: 4,
                  right: 4,
                  height: (widget.height - extrusionHeight) * 0.4,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(borderRadius - 2),
                        bottom: const Radius.circular(4),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.65),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),

                // Button Content: Icon + Embossed Text Label
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(
                        widget.icon,
                        color: widget.textColor ?? theme.textColor,
                        size: isCompact ? 18 : 22,
                        shadows: theme.isLightText
                            ? [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.8),
                                  offset: const Offset(0, 1.5),
                                  blurRadius: 2,
                                ),
                              ]
                            : [
                                Shadow(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  offset: const Offset(0, 1),
                                  blurRadius: 0.5,
                                ),
                              ],
                      ),
                      SizedBox(width: isCompact ? 5 : 8),
                    ],
                    Flexible(
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: widget.textColor ?? theme.textColor,
                          fontWeight: FontWeight.w900,
                          fontSize: effectiveFontSize,
                          letterSpacing: 0.4,
                          shadows: theme.isLightText
                              ? [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.9),
                                    offset: const Offset(0, 1.5),
                                    blurRadius: 2,
                                  ),
                                ]
                              : [
                                  Shadow(
                                    color: Colors.white.withValues(alpha: 0.75),
                                    offset: const Offset(0, 1),
                                    blurRadius: 0,
                                  ),
                                ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _ButtonThemeData _resolveTheme(Gradient? gradient) {
    if (gradient == null || gradient == AppColors.goldGradient) {
      // Default: Radiant 2.5D Gold Jewel
      return const _ButtonThemeData(
        faceGradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFF9C4), // Top glistening white-gold
            Color(0xFFFFD54F), // Radiant gold
            Color(0xFFFFB300), // Deep amber
            Color(0xFFE65100), // 3D beveled base
          ],
          stops: [0.0, 0.35, 0.75, 1.0],
        ),
        extrusionColor: Color(0xFF6B2800), // Solid dark amber ledge
        rimBorderColor: Color(0xFFFFF099),
        glowColor: AppColors.gold,
        textColor: Color(0xFF140728), // Stamped royal navy
        isLightText: false,
      );
    }

    if (gradient is LinearGradient && gradient.colors.isNotEmpty) {
      final first = gradient.colors.first;
      // Check if it's teal-based
      if (first == AppColors.teal ||
          gradient.colors.contains(AppColors.teal)) {
        return const _ButtonThemeData(
          faceGradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFA5FFF9), // Specular light cyan
              Color(0xFF26E0D8), // Radiant teal
              Color(0xFF009688), // Deep cyan
              Color(0xFF004D40), // Beveled dark teal base
            ],
            stops: [0.0, 0.35, 0.75, 1.0],
          ),
          extrusionColor: Color(0xFF002922),
          rimBorderColor: Color(0xFFB2FFFA),
          glowColor: AppColors.teal,
          textColor: Color(0xFF021B1A),
          isLightText: false,
        );
      }
      // Check if it's magenta / purple-based
      if (first == AppColors.magenta ||
          gradient.colors.contains(AppColors.magenta)) {
        return const _ButtonThemeData(
          faceGradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFF94E8), // Specular magenta pink
              Color(0xFFE040FB), // Electric magenta
              Color(0xFFAA00FF), // Deep purple
              Color(0xFF4A148C), // Beveled base
            ],
            stops: [0.0, 0.35, 0.75, 1.0],
          ),
          extrusionColor: Color(0xFF2A0042),
          rimBorderColor: Color(0xFFFFB8F2),
          glowColor: AppColors.magenta,
          textColor: Colors.white,
          isLightText: true,
        );
      }
    }

    // Generic fallback with custom gradient
    return _ButtonThemeData(
      faceGradient: gradient,
      extrusionColor: const Color(0xFF0A0216),
      rimBorderColor: Colors.white.withValues(alpha: 0.4),
      glowColor: AppColors.purple,
      textColor: Colors.white,
      isLightText: true,
    );
  }
}

class _ButtonThemeData {
  final Gradient faceGradient;
  final Color extrusionColor;
  final Color rimBorderColor;
  final Color glowColor;
  final Color textColor;
  final bool isLightText;

  const _ButtonThemeData({
    required this.faceGradient,
    required this.extrusionColor,
    required this.rimBorderColor,
    required this.glowColor,
    required this.textColor,
    required this.isLightText,
  });
}
