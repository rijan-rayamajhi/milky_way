import 'dart:math';
import 'package:flutter/material.dart';
import '../services/real_play_service.dart';
import '../theme/app_theme.dart';
import 'currency_bar.dart';

enum WinTier { none, big, mega, epic }

/// Tier from win size relative to the bet.
WinTier winTierFor(int win, int totalBet) {
  if (totalBet <= 0 || win <= 0) return WinTier.none;
  final r = win / totalBet;
  if (r >= 50) return WinTier.epic;
  if (r >= 25) return WinTier.mega;
  if (r >= 10) return WinTier.big;
  return WinTier.none;
}

/// Full-screen celebration: coin rain + count-up amount + tier banner.
/// Inserted into the Overlay so it floats above the game; auto-dismisses.
void showWinCelebration(BuildContext context, int amount, WinTier tier) {
  if (tier == WinTier.none) return;
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _WinCelebration(
      amount: amount,
      tier: tier,
      onDone: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _WinCelebration extends StatefulWidget {
  final int amount;
  final WinTier tier;
  final VoidCallback onDone;
  const _WinCelebration(
      {required this.amount, required this.tier, required this.onDone});

  @override
  State<_WinCelebration> createState() => _WinCelebrationState();
}

class _WinCelebrationState extends State<_WinCelebration>
    with TickerProviderStateMixin {
  late final AnimationController _in;
  late final AnimationController _rain;
  bool _closing = false;

  (String, Color) get _label => switch (widget.tier) {
        WinTier.epic => ('EPIC WIN', AppColors.magenta),
        WinTier.mega => ('MEGA WIN', AppColors.gold),
        WinTier.big => ('BIG WIN', AppColors.teal),
        WinTier.none => ('', Colors.white),
      };

  Duration get _hold => switch (widget.tier) {
        WinTier.epic => const Duration(milliseconds: 4600),
        WinTier.mega => const Duration(milliseconds: 4000),
        _ => const Duration(milliseconds: 3600),
      };

  @override
  void initState() {
    super.initState();
    _in = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500))
      ..forward();
    _rain = AnimationController(vsync: this, duration: _hold)..forward();
    // No auto-dismiss — the player taps to continue (see GestureDetector below).
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    _in.reverse().then((_) => widget.onDone());
  }

  @override
  void dispose() {
    _in.dispose();
    _rain.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (text, color) = _label;
    final coins = widget.tier == WinTier.epic
        ? 46
        : widget.tier == WinTier.mega
            ? 32
            : 20;
    return GestureDetector(
      onTap: _close,
      child: FadeTransition(
        opacity: _in,
        child: Material(
          color: Colors.black.withValues(alpha: 0.72),
          child: Stack(
            children: [
              _CoinRain(controller: _rain, count: coins),
              Center(
                child: ScaleTransition(
                  scale: CurvedAnimation(parent: _in, curve: Curves.elasticOut),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        text,
                        style: TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w900,
                          color: color,
                          letterSpacing: 1.5,
                          shadows: [
                            Shadow(color: color, blurRadius: 24),
                            const Shadow(color: Colors.black, blurRadius: 4),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      CountUpText(
                        amount: widget.amount,
                        duration: const Duration(milliseconds: 1200),
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          shadows: [Shadow(color: AppColors.gold, blurRadius: 16)],
                        ),
                      ),
                      const SizedBox(height: 22),
                      // Real Money Jackpot Upsell Banner
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          RealPlayService.openRealPlay();
                          _close();
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 32),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF381503), Color(0xFF1E0800)],
                            ),
                            border: Border.all(
                              color: const Color(0xFFFFB300),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF8F00).withValues(alpha: 0.5),
                                blurRadius: 16,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.workspace_premium_rounded,
                                color: Color(0xFFFFD54F),
                                size: 26,
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'WIN REAL CASH JACKPOTS!',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Color(0xFFFFD54F),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      '100% Match Bonus on SpinnerLog',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFFFB300), Color(0xFFFF6F00)],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'PLAY REAL',
                                      style: TextStyle(
                                        color: Color(0xFF1F0800),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 10.5,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                    SizedBox(width: 3),
                                    Icon(
                                      Icons.open_in_new_rounded,
                                      color: Color(0xFF1F0800),
                                      size: 13,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'TAP TO CONTINUE',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          letterSpacing: 1.5,
                        ),
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
}

/// Counts an integer up from 0 to [amount] once.
class CountUpText extends StatelessWidget {
  final int amount;
  final Duration duration;
  final TextStyle style;
  final String prefix;
  const CountUpText({
    super.key,
    required this.amount,
    required this.style,
    this.duration = const Duration(milliseconds: 800),
    this.prefix = '',
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: amount),
      duration: duration,
      curve: Curves.easeOut,
      builder: (_, v, child) =>
          Text('$prefix${CurrencyBar.format(v)}', style: style),
    );
  }
}

class _CoinRain extends StatelessWidget {
  final AnimationController controller;
  final int count;
  const _CoinRain({required this.controller, required this.count});

  @override
  Widget build(BuildContext context) {
    final rng = Random(count); // stable layout for this burst
    final size = MediaQuery.of(context).size;
    final coins = List.generate(count, (i) {
      final startX = rng.nextDouble() * size.width;
      final delay = rng.nextDouble() * 0.4;
      final speed = 0.6 + rng.nextDouble() * 0.4;
      final spin = (rng.nextBool() ? 1 : -1) * (1 + rng.nextDouble() * 2);
      final scale = 0.5 + rng.nextDouble() * 0.6;
      return (startX, delay, speed, spin, scale);
    });

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        return Stack(
          children: [
            for (final (x, delay, speed, spin, scale) in coins)
              _coin(size, t, x, delay, speed, spin, scale),
          ],
        );
      },
    );
  }

  Widget _coin(Size size, double t, double x, double delay, double speed,
      double spin, double scale) {
    final p = ((t - delay) / speed).clamp(0.0, 1.0);
    if (p <= 0) return const SizedBox.shrink();
    final y = -60 + p * (size.height + 120);
    return Positioned(
      left: x,
      top: y,
      child: Transform.rotate(
        angle: p * spin * 2 * pi,
        child: Transform.scale(
          scale: scale,
          child: Image.asset('assets/images/currency/coin.png',
              width: 44, height: 44),
        ),
      ),
    );
  }
}

/// Wraps a winning cell in a gentle repeating pulse while [active].
class PulseGlow extends StatefulWidget {
  final bool active;
  final Widget child;
  const PulseGlow({super.key, required this.active, required this.child});

  @override
  State<PulseGlow> createState() => _PulseGlowState();
}

class _PulseGlowState extends State<PulseGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(PulseGlow old) {
    super.didUpdateWidget(old);
    if (widget.active && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!widget.active && _c.isAnimating) {
      _c
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    return ScaleTransition(
      scale: Tween(begin: 1.0, end: 1.08).animate(
          CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: widget.child,
    );
  }
}
