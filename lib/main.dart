import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const VoiceNavApp());
}

class VoiceNavApp extends StatelessWidget {
  const VoiceNavApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice Navigation',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _text = 'Press button & speak destination';
  LatLng _currentLocation = const LatLng(31.5204, 74.3587);
  List<LatLng> _routePoints = [];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(onResult: (val) {
          setState(() {
            _text = val.recognizedWords;
          });
          if (val.finalResult && _text.isNotEmpty) {
            _searchAndRoute(_text);
          }
        });
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Future<void> _searchAndRoute(String query) async {
    try {
      final geoUrl = Uri.parse('https://nominatim.openstreetmap.org/search?format=json&q=$query');
      final geoRes = await http.get(geoUrl, headers: {'User-Agent': 'VoiceNavApp'});
      
      if (geoRes.statusCode == 200 && jsonDecode(geoRes.body).isNotEmpty) {
        final data = jsonDecode(geoRes.body)[0];
        double lat = double.parse(data['lat']);
        double lon = double.parse(data['lon']);
        LatLng dest = LatLng(lat, lon);

        final osrmUrl = Uri.parse('http://router.project-osrm.org/route/v1/driving/${_currentLocation.longitude},${_currentLocation.latitude};$lon,$lat?overview=full&geometries=geojson');
        final routeRes = await http.get(osrmUrl);

        if (routeRes.statusCode == 200) {
          final routeData = jsonDecode(routeRes.body);
          final coords = routeData['routes'][0]['geometry']['coordinates'] as List;
          
          setState(() {
            _routePoints = coords.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();
          });

          _mapController.move(dest, 13.0);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error finding route: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Voice Navigation AI')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation,
              initialZoom: 12.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.voice_nav_app',
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routePoints,
                    strokeWidth: 4.0,
                    color: Colors.blue,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _currentLocation,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.my_location, color: Colors.red, size: 30),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 15,
            left: 15,
            right: 15,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  _text,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _listen,
        child: Icon(_isListening ? Icons.mic : Icons.mic_none),
      ),
    );
  }
}
