import 'package:flutter/material.dart';
import '../models/slot_game.dart';
import '../theme/app_theme.dart';

/// Placeholder game screen. The shared SlotEngine lands here in Phase 2.
class GameScreen extends StatelessWidget {
  final SlotGame game;
  const GameScreen({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(game.asset, width: 180),
                      const SizedBox(height: 16),
                      Text(game.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Text(game.tagline,
                          style: const TextStyle(color: AppColors.textDim)),
                      const SizedBox(height: 24),
                      const Text('Coming in Phase 2',
                          style: TextStyle(color: AppColors.gold)),
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
