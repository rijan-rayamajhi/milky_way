import 'package:flutter/material.dart';
import '../services/sound_service.dart';
import '../services/wallet_service.dart';
import '../theme/app_theme.dart';

import 'coin_fly_overlay.dart';

/// Top lobby bar: avatar + level + XP, and coin/gem balances with a + button.
class CurrencyBar extends StatelessWidget {
  final WalletService wallet;
  final VoidCallback onGetCoins;

  const CurrencyBar({super.key, required this.wallet, required this.onGetCoins});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: wallet,
      builder: (context, _) => Row(
        children: [
          _avatar(),
          const SizedBox(width: 8),
          _balance(
            'assets/images/currency/coin.png',
            wallet.coins,
            CurrencyGainType.coin,
            onAdd: onGetCoins,
          ),
          const SizedBox(width: 8),
          _balance(
            'assets/images/currency/gem.png',
            wallet.gems,
            CurrencyGainType.gem,
          ),
        ],
      ),
    );
  }

  Widget _avatar() {
    return SizedBox(
      width: 86,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              Image.asset('assets/images/avatar/avatar_frame.png',
                  width: 52, height: 52),
              Positioned(
                bottom: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1.5),
                  decoration: BoxDecoration(
                    gradient: AppColors.goldGradient,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF2A1502), width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0xFF0A0216),
                        offset: Offset(0, 2),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Text('Lv ${wallet.level}',
                      style: const TextStyle(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w900,
                          fontSize: 11)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 7,
            padding: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              color: const Color(0xFF090216),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.45),
                width: 0.8,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  offset: Offset(0, 1),
                  blurRadius: 1,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  FractionallySizedBox(
                    widthFactor: wallet.levelProgress.clamp(0.02, 1.0),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.teal, Color(0xFF4DFBD0), AppColors.teal],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _balance(
    String icon,
    int value,
    CurrencyGainType gainType, {
    VoidCallback? onAdd,
  }) {
    return Expanded(
      child: Container(
        height: 40,
        padding: const EdgeInsets.only(left: 6, right: 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1D1138),
              Color(0xFF0F0624),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: gainType == CurrencyGainType.coin
                ? AppColors.gold.withValues(alpha: 0.65)
                : AppColors.teal.withValues(alpha: 0.65),
            width: 1.2,
          ),
          boxShadow: [
            // 2.5D solid drop extrusion
            const BoxShadow(
              color: Color(0xFF060012),
              offset: Offset(0, 3),
              blurRadius: 0,
            ),
            // Soft glow
            BoxShadow(
              color: (gainType == CurrencyGainType.coin
                      ? AppColors.gold
                      : AppColors.teal)
                  .withValues(alpha: 0.25),
              offset: const Offset(0, 1),
              blurRadius: 6,
            ),
          ],
        ),
        child: Row(
          children: [
            Image.asset(icon, width: 26, height: 26),
            const SizedBox(width: 6),
            Expanded(
              child: RollingNumberText(
                value: value,
                gainType: gainType,
                formatter: format,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  shadows: [
                    Shadow(
                      color: Colors.black87,
                      offset: Offset(0, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
            if (onAdd != null) _TactileAddButton(onTap: onAdd),
          ],
        ),
      ),
    );
  }

  /// Public number formatter reused across slot screens.
  static String format(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 10000) return '${(n / 1000).toStringAsFixed(1)}K';
    // group thousands
    final s = n.toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }
}

class _TactileAddButton extends StatefulWidget {
  final VoidCallback onTap;
  const _TactileAddButton({required this.onTap});

  @override
  State<_TactileAddButton> createState() => _TactileAddButtonState();
}

class _TactileAddButtonState extends State<_TactileAddButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
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
        transform: Matrix4.translationValues(0, _down ? 2.0 : 0.0, 0),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF9C4),
              Color(0xFFFFD54F),
              Color(0xFFFFB300),
              Color(0xFFE65100),
            ],
            stops: [0.0, 0.35, 0.75, 1.0],
          ),
          border: Border.all(color: const Color(0xFFFFF099), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6B2800),
              offset: Offset(0, _down ? 0.8 : 2.5),
              blurRadius: 0,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              offset: Offset(0, _down ? 1.5 : 3.5),
              blurRadius: 3,
            ),
          ],
        ),
        child: const Center(
          child: Icon(Icons.add, color: Color(0xFF140728), size: 18),
        ),
      ),
    );
  }
}
