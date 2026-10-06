import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/sound_service.dart';
import '../services/wallet_service.dart';
import '../theme/app_theme.dart';
import 'currency_bar.dart';

/// Global controller to register target positions and trigger coin/gem fly effects.
class CoinFlyService {
  static Offset? _customCoinTarget;
  static Offset? _customGemTarget;

  static void setCoinTarget(Offset? offset) => _customCoinTarget = offset;
  static void setGemTarget(Offset? offset) => _customGemTarget = offset;

  static final StreamController<CurrencyGainType> _impactController =
      StreamController<CurrencyGainType>.broadcast();
  static Stream<CurrencyGainType> get onImpact => _impactController.stream;

  static void notifyImpact(CurrencyGainType type) {
    _impactController.add(type);
  }

  static Offset getCoinTarget(BuildContext context) {
    if (_customCoinTarget != null) return _customCoinTarget!;
    final size = MediaQuery.sizeOf(context);
    final top = MediaQuery.paddingOf(context).top;
    return Offset(size.width * 0.46, top + 26);
  }

  static Offset getGemTarget(BuildContext context) {
    if (_customGemTarget != null) return _customGemTarget!;
    final size = MediaQuery.sizeOf(context);
    final top = MediaQuery.paddingOf(context).top;
    return Offset(size.width * 0.82, top + 26);
  }
}

/// Overlay container that sits on top of the entire app to render flying coins/gems.
class CoinFlyOverlay extends StatefulWidget {
  final WalletService wallet;
  final Widget child;

  const CoinFlyOverlay({
    super.key,
    required this.wallet,
    required this.child,
  });

  @override
  State<CoinFlyOverlay> createState() => CoinFlyOverlayState();
}

class CoinFlyOverlayState extends State<CoinFlyOverlay>
    with TickerProviderStateMixin {
  StreamSubscription<CurrencyGainEvent>? _sub;
  final List<_ParticleCluster> _clusters = [];
  final List<_ImpactRipple> _ripples = [];

  @override
  void initState() {
    super.initState();
    _sub = widget.wallet.onCurrencyGain.listen(_onGain);
  }

  @override
  void didUpdateWidget(CoinFlyOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wallet != widget.wallet) {
      _sub?.cancel();
      _sub = widget.wallet.onCurrencyGain.listen(_onGain);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    for (final c in _clusters) {
      c.controller.dispose();
    }
    for (final r in _ripples) {
      r.controller.dispose();
    }
    super.dispose();
  }

  void _onGain(CurrencyGainEvent event) {
    if (!mounted) return;
    spawnFly(
      type: event.type,
      amount: event.amount,
      origin: event.origin,
    );
  }

  /// Public entry to trigger flying coins/gems from any UI point.
  void spawnFly({
    required CurrencyGainType type,
    required int amount,
    Offset? origin,
  }) {
    // One coin-increase chime per gain (not per particle).
    if (type == CurrencyGainType.coin) sound.coin();

    final size = MediaQuery.sizeOf(context);
    final start = origin ?? Offset(size.width * 0.5, size.height * 0.52);
    final target = type == CurrencyGainType.coin
        ? CoinFlyService.getCoinTarget(context)
        : CoinFlyService.getGemTarget(context);

    // Dynamic particle count based on amount
    final int count = type == CurrencyGainType.coin
        ? (amount >= 50000
            ? 22
            : amount >= 10000
                ? 16
                : amount >= 2000
                    ? 12
                    : 8)
        : (amount >= 50
            ? 14
            : amount >= 10
                ? 10
                : 6);

    final controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 700 + count * 28),
    );

    final random = math.Random();
    final particles = List.generate(count, (i) {
      final angle = random.nextDouble() * 2 * math.pi;
      final burstDist = 35.0 + random.nextDouble() * 55.0;
      final burstOffset = Offset(
        math.cos(angle) * burstDist,
        math.sin(angle) * burstDist,
      );

      final delayFraction = (i * 0.038).clamp(0.0, 0.45);
      final durationFraction = 0.52;

      // Arc curvature control point
      final midX = (start.dx + target.dx) / 2 + (random.nextDouble() - 0.5) * 80;
      final midY = math.min(start.dy, target.dy) - (50 + random.nextDouble() * 70);
      final controlPoint = Offset(midX, midY);

      return _Particle(
        start: start,
        burstTarget: start + burstOffset,
        controlPoint: controlPoint,
        end: target,
        delay: delayFraction,
        flightDuration: durationFraction,
        rotationSpeed: (random.nextBool() ? 1 : -1) * (2 + random.nextDouble() * 3),
        scale: 0.85 + random.nextDouble() * 0.35,
      );
    });

    final cluster = _ParticleCluster(
      type: type,
      controller: controller,
      particles: particles,
    );

    setState(() => _clusters.add(cluster));

    // Staggered impact sounds & haptics as particles hit
    controller.addListener(() {
      for (final p in particles) {
        if (!p.hasImpacted && controller.value >= p.delay + p.flightDuration) {
          p.hasImpacted = true;
          _triggerImpact(target, type);
        }
      }
    });

    controller.forward().then((_) {
      if (mounted) {
        setState(() {
          _clusters.remove(cluster);
          controller.dispose();
        });
      }
    });
  }

  void _triggerImpact(Offset target, CurrencyGainType type) {
    CoinFlyService.notifyImpact(type);
    sound.hapticSelection();

    final rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    final ripple = _ImpactRipple(
      target: target,
      type: type,
      controller: rippleController,
    );

    setState(() => _ripples.add(ripple));

    rippleController.forward().then((_) {
      if (mounted) {
        setState(() {
          _ripples.remove(ripple);
          rippleController.dispose();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,

        // Flying coins & gems particle layer
        if (_clusters.isNotEmpty || _ripples.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                animation: Listenable.merge(
                  [
                    ..._clusters.map((c) => c.controller),
                    ..._ripples.map((r) => r.controller),
                  ],
                ),
                builder: (context, _) {
                  return CustomPaint(
                    painter: _FlyingParticlePainter(
                      clusters: _clusters,
                      ripples: _ripples,
                    ),
                  );
                },
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ParticleCluster {
  final CurrencyGainType type;
  final AnimationController controller;
  final List<_Particle> particles;

  _ParticleCluster({
    required this.type,
    required this.controller,
    required this.particles,
  });
}

class _Particle {
  final Offset start;
  final Offset burstTarget;
  final Offset controlPoint;
  final Offset end;
  final double delay;
  final double flightDuration;
  final double rotationSpeed;
  final double scale;
  bool hasImpacted = false;

  _Particle({
    required this.start,
    required this.burstTarget,
    required this.controlPoint,
    required this.end,
    required this.delay,
    required this.flightDuration,
    required this.rotationSpeed,
    required this.scale,
  });

  Offset computePosition(double t) {
    if (t < delay) {
      return start;
    }

    final localT = ((t - delay) / flightDuration).clamp(0.0, 1.0);

    // Initial 20% is radial burst, remaining 80% is curved Bezier flight
    if (localT < 0.20) {
      final burstT = Curves.easeOutCubic.transform(localT / 0.20);
      return Offset.lerp(start, burstTarget, burstT)!;
    } else {
      final flightT = Curves.easeInOutCubic.transform((localT - 0.20) / 0.80);
      // Quadratic Bezier: B(t) = (1-t)^2 * P0 + 2(1-t)t * P1 + t^2 * P2
      final oneMinusT = 1.0 - flightT;
      return burstTarget * (oneMinusT * oneMinusT) +
          controlPoint * (2 * oneMinusT * flightT) +
          end * (flightT * flightT);
    }
  }

  double computeOpacity(double t) {
    if (t < delay) return 0.0;
    final localT = ((t - delay) / flightDuration).clamp(0.0, 1.0);
    if (localT < 0.08) return localT / 0.08;
    if (localT > 0.92) return (1.0 - localT) / 0.08;
    return 1.0;
  }

  double computeScale(double t) {
    if (t < delay) return 0.0;
    final localT = ((t - delay) / flightDuration).clamp(0.0, 1.0);
    if (localT < 0.20) {
      // Pop open during burst
      return (localT / 0.20) * scale * 1.15;
    } else {
      final flightT = (localT - 0.20) / 0.80;
      return (1.15 - 0.35 * flightT) * scale;
    }
  }
}

class _ImpactRipple {
  final Offset target;
  final CurrencyGainType type;
  final AnimationController controller;

  _ImpactRipple({
    required this.target,
    required this.type,
    required this.controller,
  });
}

class _FlyingParticlePainter extends CustomPainter {
  final List<_ParticleCluster> clusters;
  final List<_ImpactRipple> ripples;

  _FlyingParticlePainter({
    required this.clusters,
    required this.ripples,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Paint Impact Ripples at target
    for (final r in ripples) {
      final t = r.controller.value;
      final radius = 10.0 + t * 28.0;
      final opacity = (1.0 - t).clamp(0.0, 1.0);
      final isCoin = r.type == CurrencyGainType.coin;

      final paint = Paint()
        ..color = (isCoin ? AppColors.gold : AppColors.teal)
            .withValues(alpha: opacity * 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0 * (1.0 - t * 0.6);

      canvas.drawCircle(r.target, radius, paint);

      // Flash glow core
      final corePaint = Paint()
        ..color = (isCoin ? const Color(0xFFFFF9C4) : const Color(0xFFE0F7FA))
            .withValues(alpha: opacity * 0.9)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(r.target, 5.0 * (1.0 - t), corePaint);
    }

    // 2. Paint Flying Coins & Gems
    for (final cluster in clusters) {
      final t = cluster.controller.value;
      final isCoin = cluster.type == CurrencyGainType.coin;

      for (final p in cluster.particles) {
        if (t < p.delay) continue;
        final opacity = p.computeOpacity(t);
        if (opacity <= 0.01) continue;

        final pos = p.computePosition(t);
        final scale = p.computeScale(t);
        final angle = t * p.rotationSpeed * 2 * math.pi;

        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(angle);
        canvas.scale(scale);

        if (isCoin) {
          _drawCoin(canvas, opacity);
        } else {
          _drawGem(canvas, opacity);
        }

        canvas.restore();
      }
    }
  }

  void _drawCoin(Canvas canvas, double opacity) {
    const radius = 12.0;

    // Soft aura (plain translucent fill — no per-frame blur, far cheaper).
    final glowPaint = Paint()
      ..color = const Color(0xFFFFD700).withValues(alpha: 0.30 * opacity);
    canvas.drawCircle(Offset.zero, radius + 3, glowPaint);

    // Rim ring
    final rimPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFF59D), Color(0xFFFFB300), Color(0xFFE65100)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius));
    canvas.drawCircle(Offset.zero, radius, rimPaint);

    // Inner gold core
    final innerPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFFFF9C4), Color(0xFFFFC107), Color(0xFFFF8F00)],
      ).createShader(Rect.fromCircle(center: const Offset(-2, -2), radius: radius - 2.5));
    canvas.drawCircle(Offset.zero, radius - 2.5, innerPaint);

    // Inner star crest
    final starPaint = Paint()
      ..color = const Color(0xFFFFFDE7).withValues(alpha: 0.9 * opacity)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset.zero, 3.2, starPaint);
  }

  void _drawGem(Canvas canvas, double opacity) {
    const size = 11.0;

    // Cyan aura (plain translucent fill — no per-frame blur).
    final glowPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.32 * opacity);
    canvas.drawCircle(Offset.zero, size + 3, glowPaint);

    // Diamond polygon
    final path = Path()
      ..moveTo(0, -size)
      ..lineTo(size, 0)
      ..lineTo(0, size)
      ..lineTo(-size, 0)
      ..close();

    final gemPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFE0F7FA), Color(0xFF00E5FF), Color(0xFF0097A7)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: size));
    canvas.drawPath(path, gemPaint);

    // Facet glint
    final glintPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawLine(const Offset(-size * 0.5, 0), const Offset(size * 0.5, 0), glintPaint);
    canvas.drawLine(const Offset(0, -size * 0.5), const Offset(0, size * 0.5), glintPaint);
  }

  @override
  bool shouldRepaint(covariant _FlyingParticlePainter oldDelegate) => true;
}

// -----------------------------------------------------------------------------
// ROLLING NUMBER TEXT WIDGET
// -----------------------------------------------------------------------------

/// Rolling counter that smoothly animates upward when balance increases.
class RollingNumberText extends StatefulWidget {
  final int value;
  final TextStyle style;
  final String Function(int)? formatter;
  final Duration duration;
  final CurrencyGainType? gainType;

  const RollingNumberText({
    super.key,
    required this.value,
    required this.style,
    this.formatter,
    this.duration = const Duration(milliseconds: 950),
    this.gainType,
  });

  @override
  State<RollingNumberText> createState() => _RollingNumberTextState();
}

class _RollingNumberTextState extends State<RollingNumberText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int _oldValue = 0;
  int _targetValue = 0;
  StreamSubscription<CurrencyGainType>? _impactSub;
  double _pillPunch = 1.0;

  @override
  void initState() {
    super.initState();
    _oldValue = widget.value;
    _targetValue = widget.value;

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    if (widget.gainType != null) {
      _impactSub = CoinFlyService.onImpact.listen((type) {
        if (type == widget.gainType && mounted) {
          setState(() => _pillPunch = 1.15);
          Future.delayed(const Duration(milliseconds: 90), () {
            if (mounted) setState(() => _pillPunch = 1.0);
          });
        }
      });
    }
  }

  @override
  void didUpdateWidget(RollingNumberText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _oldValue = (_animation.value * (_targetValue - _oldValue) + _oldValue).round();
      _targetValue = widget.value;

      _controller.duration = widget.value > _oldValue
          ? widget.duration
          : const Duration(milliseconds: 260);

      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _impactSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pillPunch,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOutBack,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, _) {
          final current =
              (_oldValue + (_targetValue - _oldValue) * _animation.value).round();
          final formatted = widget.formatter != null
              ? widget.formatter!(current)
              : CurrencyBar.format(current);

          final isIncreasing = _targetValue > _oldValue && _controller.isAnimating;

          return Text(
            formatted,
            overflow: TextOverflow.ellipsis,
            style: widget.style.copyWith(
              color: isIncreasing
                  ? (widget.gainType == CurrencyGainType.gem
                      ? const Color(0xFF80DEEA)
                      : const Color(0xFFFFF59D))
                  : widget.style.color,
              shadows: [
                if (isIncreasing)
                  Shadow(
                    color: (widget.gainType == CurrencyGainType.gem
                            ? AppColors.teal
                            : AppColors.gold)
                        .withValues(alpha: 0.8),
                    blurRadius: 8,
                  ),
                ...?widget.style.shadows,
              ],
            ),
          );
        },
      ),
    );
  }
}
