import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../controllers/assistant_controller.dart';
import '../models/assistant_state.dart';

class AiCharacterOverlay extends StatelessWidget {
  const AiCharacterOverlay({super.key});

  String _statusText(AssistantState state) {
    switch (state) {
      case AssistantState.idle:
        return 'Tap the mic to speak';
      case AssistantState.listening:
        return 'Listening...';
      case AssistantState.processing:
        return 'Thinking...';
      case AssistantState.speaking:
        return 'Speaking...';
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AssistantController>();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 200,
          child: Lottie.asset('assets/animations/avatar.json'),
        ),
        const SizedBox(height: 8),
        Text(
          controller.lastText.isNotEmpty
              ? controller.lastText
              : _statusText(controller.state),
          style: const TextStyle(fontSize: 16),
        ),
      ],
    );
  }
}
