import 'package:flutter/material.dart';
import '../services/sound_service.dart';
import '../theme/app_theme.dart';

/// Code-generated glossy gradient button (no image asset needed).
class CosmicButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Gradient gradient;
  final double height;
  final double? width;

  const CosmicButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.gradient = AppColors.goldGradient,
    this.height = 54,
    this.width,
  });

  @override
  State<CosmicButton> createState() => _CosmicButtonState();
}

class _CosmicButtonState extends State<CosmicButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTap: enabled
          ? () {
              sound.tap();
              widget.onTap!();
            }
          : null,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1,
        duration: const Duration(milliseconds: 90),
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Container(
            height: widget.height,
            width: widget.width,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            decoration: BoxDecoration(
              gradient: widget.gradient,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.teal.withValues(alpha: 0.6), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: widget.gradient.colors.first.withValues(alpha: 0.5),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, color: AppColors.navy, size: 22),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    widget.label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
