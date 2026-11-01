import 'package:flutter/material.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/mascot/eve_mascot.dart';
import 'package:eve_app/shared/widgets/eve_components.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onContinue, this.onJoinPartner});

  final VoidCallback onContinue;

  /// "Joining a partner?" link shown under Begin Setup when set.
  final VoidCallback? onJoinPartner;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 32),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0F4),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Welcome to EVE. Let us personalize your health and cycle tracking experience.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const EveMascot(emotion: EveEmotion.neutral, size: 180),
              const Column(
                children: [
                  Text('EVE', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                  Text('Cycle & Wellness Companion', style: TextStyle(color: Color(0xFF666666))),
                ],
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  EveButton(
                    key: const Key('welcome-begin-setup-button'),
                    label: 'Begin Setup',
                    onPressed: onContinue,
                  ),
                  if (onJoinPartner != null)
                    TextButton(
                      key: const Key('welcome-partner-join'),
                      onPressed: onJoinPartner,
                      child: const Text('Joining a partner? Enter an invite code'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
