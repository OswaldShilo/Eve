import 'package:flutter/material.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/mascot/eve_mascot.dart';

class CompletionScreen extends StatelessWidget {
  const CompletionScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

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
                    'Your EVE profile setup is complete.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const EveMascot(emotion: EveEmotion.hype, size: 180),
              const Column(
                children: [
                  Text('All Set!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                  Text('Tailored specifically for your health journey', style: TextStyle(color: Color(0xFF666666))),
                ],
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const Key('completion-enter-eve-button'),
                  onPressed: onContinue,
                  child: const Text('Enter EVE'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
