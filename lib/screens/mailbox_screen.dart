import 'package:flutter/material.dart';
import '../services/engagement_service.dart';
import '../services/wallet_service.dart';
import '../theme/app_theme.dart';
import '../widgets/cosmic_button.dart';
import '../widgets/currency_bar.dart';

class MailboxScreen extends StatelessWidget {
  final EngagementService eng;
  final WalletService wallet;
  const MailboxScreen({super.key, required this.eng, required this.wallet});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: ListenableBuilder(
            listenable: eng,
            builder: (context, _) {
              final gifts = eng.mailbox;
              return Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text('Mailbox',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800)),
                      const Spacer(),
                      if (gifts.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: CosmicButton(
                            label: 'Claim All',
                            height: 40,
                            onTap: () => eng.claimAll(wallet),
                          ),
                        ),
                    ],
                  ),
                  Expanded(
                    child: gifts.isEmpty
                        ? const Center(
                            child: Text('No gifts right now.\nLevel up to earn rewards!',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textDim)),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: gifts.length,
                            separatorBuilder: (_, i) => const SizedBox(height: 10),
                            itemBuilder: (context, i) => _tile(gifts[i]),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _tile(Gift g) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.deepPurple,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Image.asset('assets/images/engagement/reward_chest.png', width: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(g.title,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  '${CurrencyBar.format(g.coins)} coins'
                  '${g.gems > 0 ? '  ·  ${g.gems} gems' : ''}',
                  style: const TextStyle(color: AppColors.gold, fontSize: 12),
                ),
              ],
            ),
          ),
          CosmicButton(
            label: 'Claim',
            height: 38,
            onTap: () => eng.claimGift(wallet, g.id),
          ),
        ],
      ),
    );
  }
}
