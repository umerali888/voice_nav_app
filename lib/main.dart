import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

void main() {
  runApp(const VoiceNavApp());
}

class VoiceNavApp extends StatelessWidget {
  const VoiceNavApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Voice Navigation AI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _text = 'Press button & speak destination';
String _selectedLocale = 'en_US';

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) => print('onStatus: $val'),
        onError: (val) => print('onError: $val'),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          localeId: _selectedLocale,
          onResult: (val) => setState(() {
            _text = val.recognizedWords;
          }),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
       appBar: AppBar(
        title: const Text('Voice Navigation AI'),
        centerTitle: true,
        actions: [
          DropdownButton<String>(
            value: _selectedLocale,
            dropdownColor: Colors.white,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'en_US', child: Text('English')),
              DropdownMenuItem(value: 'ur_PK', child: Text('Urdu')),
              DropdownMenuItem(value: 'ar_SA', child: Text('Arabic')),
              DropdownMenuItem(value: 'fr_FR', child: Text('Français')),
              DropdownMenuItem(value: 'es_ES', child: Text('Español')),
              DropdownMenuItem(value: 'hi_IN', child: Text('Hindi')),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() => _selectedLocale = val);
              }
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: const MapOptions(
              initialCenter: LatLng(33.6844, 73.0479),
              initialZoom: 13,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.voice_nav_app',
              ),
            ],
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 250,
                  width: 250,
                  child: Lottie.asset(
                    'assets/avatar.json',
                    animate: _isListening,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.smart_toy, size: 100, color: Colors.deepPurple);
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _text,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _listen,
        icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
        label: Text(_isListening ? 'Listening...' : 'Start Voice Search'),
      ),
    );
  }
}
