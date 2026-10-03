import 'package:flutter/material.dart';
import '../services/sound_service.dart';
import '../services/wallet_service.dart';
import '../theme/app_theme.dart';

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
          _balance('assets/images/currency/coin.png', _fmt(wallet.coins),
              onAdd: onGetCoins),
          const SizedBox(width: 8),
          _balance('assets/images/currency/gem.png', _fmt(wallet.gems)),
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                  decoration: BoxDecoration(
                    gradient: AppColors.goldGradient,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.navy, width: 1.5),
                  ),
                  child: Text('Lv ${wallet.level}',
                      style: const TextStyle(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w800,
                          fontSize: 11)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: wallet.levelProgress,
              minHeight: 5,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(AppColors.teal),
            ),
          ),
        ],
      ),
    );
  }

  Widget _balance(String icon, String value, {VoidCallback? onAdd}) {
    return Expanded(
      child: Container(
        height: 40,
        padding: const EdgeInsets.only(left: 6, right: 4),
        decoration: BoxDecoration(
          color: AppColors.navy.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Image.asset(icon, width: 26, height: 26),
            const SizedBox(width: 6),
            Expanded(
              child: Text(value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
            ),
            if (onAdd != null) _TactileAddButton(onTap: onAdd),
          ],
        ),
      ),
    );
  }

  static String _fmt(int n) => format(n);

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
