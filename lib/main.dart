import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'services/ai_service.dart';

void main() {
  runApp(const VoiceNavApp());
}

class VoiceNavApp extends StatelessWidget {
  const VoiceNavApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Navigation Assistant',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Colors.cyanAccent,
          secondary: Colors.blueAccent,
        ),
      ),
      home: const NavigationScreen(),
    );
  }
}

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _isListening = false;
  bool _isProcessing = false;
  String _statusText = "نیویگیشن کے لیے مائیک کا بٹن دبائیں";
  String _urduResponseText = "";
  
  List<LatLng> _routePoints = [];
  LatLng _currentLocation = const LatLng(29.7952, 72.8628); // Chishtian Default

  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _initTts();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  void _initTts() async {
    await _tts.setLanguage("ur-PK");
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5);
  }

  Future<void> _speakUrdu(String text) async {
    await _tts.speak(text);
  }

  void _startListening() async {
    bool available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
      onError: (errorNotification) {
        setState(() {
          _isListening = false;
          _statusText = "آواز ریکارڈ نہیں ہو سکی";
        });
      },
    );

    if (available) {
      setState(() {
        _isListening = true;
        _statusText = "سن رہا ہوں...";
      });

      _speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            setState(() {
              _isListening = false;
            });
            _handleVoiceQuery(result.recognizedWords);
          }
        },
        localeId: "ur_PK",
      );
    } else {
      setState(() {
        _statusText = "مائیک کی اجازت دستیاب نہیں ہے";
      });
    }
  }

  Future<void> _handleVoiceQuery(String userQuery) async {
    if (userQuery.trim().isEmpty) return;

    setState(() {
      _isProcessing = true;
      _statusText = "AI پروسیسنگ جاری ہے...";
    });

    AIResponse aiResponse = await AIService.processVoiceCommand(userQuery);

    setState(() {
      _isProcessing = false;
      _urduResponseText = aiResponse.replyText;
      _statusText = userQuery;
    });

    await _speakUrdu(aiResponse.replyText);

    if (aiResponse.destination != null) {
      _fetchAndDrawRoute(aiResponse.destination!);
    }
  }

  Future<void> _fetchAndDrawRoute(String destinationCity) async {
    try {
      final geoUrl = Uri.parse(
          'https://nominatim.openstreetmap.org/search?format=json&q=$destinationCity,Pakistan');
      final geoResp = await http.get(geoUrl, headers: {'User-Agent': 'VoiceNavApp'});

      if (geoResp.statusCode == 200) {
        final List geoData = jsonDecode(geoResp.body);
        if (geoData.isNotEmpty) {
          double destLat = double.parse(geoData[0]['lat']);
          double destLon = double.parse(geoData[0]['lon']);
          LatLng destPoint = LatLng(destLat, destLon);

          final osrmUrl = Uri.parse(
              'https://router.project-osrm.org/route/v1/driving/'
              '${_currentLocation.longitude},${_currentLocation.latitude};'
              '${destPoint.longitude},${destPoint.latitude}?overview=full&geometries=geojson');

          final routeResp = await http.get(osrmUrl);
          if (routeResp.statusCode == 200) {
            final routeData = jsonDecode(routeResp.body);
            final List coords = routeData['routes'][0]['geometry']['coordinates'];

            setState(() {
              _routePoints = coords.map((c) => LatLng(c[1], c[0])).toList();
            });

            _mapController.move(destPoint, 9.0);
          }
        }
      }
    } catch (e) {
      print("Route error: $e");
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map Background (CartoDB Voyager)
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation,
              initialZoom: 10.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 5.0,
                      color: Colors.blueAccent,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _currentLocation,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.my_location, color: Colors.cyanAccent, size: 30),
                  ),
                ],
              ),
            ],
          ),

          // Top Header UI
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
                boxShadow: const [
                  BoxShadow(color: Colors.black45, blurRadius: 10)
                ],
              ),
              child: Column(
                children: [
                  Text(
                    _statusText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                  if (_urduResponseText.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _urduResponseText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.cyanAccent,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // 3D Robot UI Control
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                GestureDetector(
                  onTap: _startListening,
                  child: AnimatedBuilder(
                    animation: _animController,
                    builder: (context, child) {
                      return Container(
                        height: 100,
                        width: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF0F172A),
                          border: Border.all(
                            color: _isListening
                                ? Colors.redAccent
                                : Colors.cyanAccent,
                            width: 3 + (_animController.value * 4),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (_isListening
                                      ? Colors.redAccent
                                      : Colors.cyanAccent)
                                  .withOpacity(0.5),
                              blurRadius: 20 * _animController.value,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            _isListening ? Icons.mic : Icons.android,
                            size: 50,
                            color: _isListening
                                ? Colors.redAccent
                                : Colors.cyanAccent,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _isListening ? "بولیں، میں سن رہا ہوں..." : "مائیک پر کلک کریں",
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
