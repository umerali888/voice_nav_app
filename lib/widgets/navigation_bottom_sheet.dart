import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/ai_service.dart';

class NavigationBottomSheet extends StatefulWidget {
  final Function(String destination) onLocationSelected;

  const NavigationBottomSheet({Key? key, required this.onLocationSelected}) : super(key: key);

  @override
  _NavigationBottomSheetState createState() => _NavigationBottomSheetState();
}

class _NavigationBottomSheetState extends State<NavigationBottomSheet> {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isListening = false;
  String _statusText = "Tap mic to talk...";

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  void _initTts() async {
    await _flutterTts.setLanguage("ur-PK");
    await _flutterTts.setSpeechRate(0.45);
  }

  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
  }

  void _handleVoiceInput(String userQuery) async {
    setState(() {
      _isListening = true;
      _statusText = "Thinking...";
    });

    AIResponse response = await AIService.processVoiceCommand(userQuery);

    setState(() {
      _isListening = false;
      _statusText = response.replyText;
    });

    await _speak(response.replyText);

    if (response.destination != null && response.destination!.isNotEmpty) {
      widget.onLocationSelected(response.destination!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      chi`d: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _statusText,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () {
              _handleVoiceInput("Lahore kaise jau?");
            },
            child: CircleAvatar(
              radius: 35,
              backgroundColor: _isListening ? Colors.redAccent : Colors.blueAccent,
              chi`d: Icon(
                _isListening ? Icons.mic : Icons.mic_none,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        ],
      ),
    );
  }
}