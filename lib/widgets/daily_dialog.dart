import 'package:flutter/material.dart';
import '../services/engagement_service.dart';
import '../services/wallet_service.dart';
import '../theme/app_theme.dart';
import '../widgets/cosmic_button.dart';
import '../widgets/currency_bar.dart';

Future<void> showDailyBonus(
  BuildContext context,
  EngagementService eng,
  WalletService wallet,
) {
  return showDialog(
    context: context,
    builder: (ctx) => ListenableBuilder(
      listenable: eng,
      builder: (ctx, _) {
        final claimable = eng.canClaimDaily;
        final nextDay = eng.nextStreakDay;
        return Dialog(
          backgroundColor: AppColors.deepPurple,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: AppColors.gold.withValues(alpha: 0.6)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/images/engagement/daily_wheel.png', width: 96),
                const Text('DAILY BONUS',
                    style: TextStyle(
                        color: AppColors.gold,
                        fontSize: 20,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  claimable ? 'Day $nextDay reward is ready!' : 'Come back tomorrow!',
                  style: const TextStyle(color: AppColors.textDim),
                ),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.82,
                  children: [
                    for (final r in EngagementService.ladder)
                      _dayCell(r, claimable, nextDay, eng.currentStreakDay),
                  ],
                ),
                const SizedBox(height: 16),
                CosmicButton(
                  label: claimable ? 'CLAIM DAY $nextDay' : 'COLLECTED',
                  width: double.infinity,
                  onTap: claimable
                      ? () {
                          eng.claimDaily(wallet);
                        }
                      : null,
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close',
                      style: TextStyle(color: AppColors.textDim)),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

Widget _dayCell(DailyReward r, bool claimable, int nextDay, int currentDay) {
  final isNext = claimable && r.day == nextDay;
  final claimed = r.day <= currentDay && !isNext;
  return Container(
    decoration: BoxDecoration(
      color: isNext
          ? AppColors.gold.withValues(alpha: 0.25)
          : AppColors.navy.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: isNext ? AppColors.gold : Colors.white24,
        width: isNext ? 2 : 1,
      ),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Day ${r.day}',
            style: const TextStyle(
                color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Image.asset('assets/images/currency/coin.png', width: 20, height: 20),
        Text(CurrencyBar.format(r.coins),
            style: const TextStyle(color: AppColors.gold, fontSize: 10)),
        if (r.gems > 0)
          Text('+${r.gems}💎',
              style: const TextStyle(color: AppColors.teal, fontSize: 9)),
        if (claimed)
          const Icon(Icons.check_circle, color: AppColors.teal, size: 14),
      ],
    ),
  );
}
