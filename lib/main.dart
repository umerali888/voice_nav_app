import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart' hide Marker;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

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
  late FlutterTts _tts;
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  bool _isListening = false;
  bool _isBusy = false;
  String _text = 'Press button & speak destination';
  String _selectedLocale = 'en_US';

  LatLng _currentLocation = const LatLng(33.6844, 73.0479);
  List<Marker> _markers = [];
  List<LatLng> _routePoints = [];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _tts = FlutterTts();
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        Position pos = await Geolocator.getCurrentPosition();
        setState(() {
          _currentLocation = LatLng(pos.latitude, pos.longitude);
        });
        _mapController.move(_currentLocation, 13);
      }
    } catch (e) {}
  }

  Future<void> _speak(String text) async {
    String ttsLang = _selectedLocale.replaceAll('_', '-');
    await _tts.setLanguage(ttsLang);
    await _tts.setPitch(1.1);
    await _tts.setSpeechRate(0.45);
    try {
      var voices = await _tts.getVoices;
      final list = (voices as List).cast<dynamic>();
      final femaleVoice = list.firstWhere(
        (v) => v['name'].toString().toLowerCase().contains('female'),
        orElse: () => null,
      );
      if (femaleVoice != null) {
        await _tts.setVoice({
          'name': femaleVoice['name'],
          'locale': femaleVoice['locale'],
        });
      }
    } catch (e) {}
    await _tts.speak(text);
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
            if (val.finalResult) {
              _isListening = false;
              _processCommand(_text);
            }
          }),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Future<void> _processCommand(String command) async {
    if (command.trim().isEmpty) return;
    String lower = command.toLowerCase().trim();

    final foodWords = ['restaurant', 'food', 'khana', 'کھانا', 'ریسٹورنٹ'];
    final hotelWords = ['hotel', 'hostel', 'ہوٹل', 'ہاسٹل'];
    final mallWords = ['mall', 'shopping', 'مال', 'شاپنگ'];
    final bankWords = ['bank', 'بینک'];

    if (foodWords.any((w) => lower.contains(w))) {
      await _searchNearby('amenity', 'restaurant', 'restaurants');
      return;
    } else if (hotelWords.any((w) => lower.contains(w))) {
      await _searchNearby('tourism', 'hotel', 'hotels');
      return;
    } else if (mallWords.any((w) => lower.contains(w))) {
      await _searchNearby('shop', 'mall', 'shopping malls');
      return;
    } else if (bankWords.any((w) => lower.contains(w))) {
      await _searchNearby('amenity', 'bank', 'banks');
      return;
    }

    String remainder = command.trim();
    final prefixes = [
      'take me to ',
      'navigate to ',
      'route to ',
      'directions to ',
      'go to ',
      'i want to go to ',
    ];
    String lowerRemainder = remainder.toLowerCase();
    for (var p in prefixes) {
      if (lowerRemainder.startsWith(p)) {
        remainder = remainder.substring(p.length).trim();
        break;
      }
    }

    final toSplit = RegExp(r'^(.*?)\s+to\s+(.+)$', caseSensitive: false);
    final match = toSplit.firstMatch(remainder);

    if (match != null && match.group(1)!.trim().isNotEmpty) {
      String originName = match.group(1)!.trim();
      String destName = match.group(2)!.trim();
      await _searchAndRouteFromTo(originName, destName);
    } else {
      await _searchAndRoute(remainder);
    }
  }

  Future<LatLng?> _geocode(String query) async {
    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1');
      final res = await http.get(url, headers: {'User-Agent': 'voice_nav_app'});
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          return LatLng(lat, lon);
        }
      }
    } catch (e) {}
    return null;
  }

  Future<void> _searchAndRoute(String destination) async {
    setState(() => _isBusy = true);
    await _speak('Searching for $destination');
    final dest = await _geocode(destination);
    if (dest == null) {
      await _speak('Sorry, I could not find $destination');
      setState(() => _isBusy = false);
      return;
    }
    await _getRoute(_currentLocation, dest, destination);
    setState(() => _isBusy = false);
  }

  Future<void> _searchAndRouteFromTo(String originName, String destName) async {
    setState(() => _isBusy = true);
    await _speak('Searching route from $originName to $destName');
    final origin = await _geocode(originName);
    final dest = await _geocode(destName);
    if (origin == null || dest == null) {
      await _speak('Sorry, I could not find one of the locations');
      setState(() => _isBusy = false);
      return;
    }
    await _getRoute(origin, dest, destName);
    setState(() => _isBusy = false);
  }

  Future<void> _getRoute(LatLng start, LatLng end, String label) async {
    try {
      final url = Uri.parse(
          'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson');
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final coords = route['geometry']['coordinates'] as List;
          final points = coords.map<LatLng>((c) => LatLng(c[1], c[0])).toList();
          final distanceKm = (route['distance'] / 1000).toStringAsFixed(1);
          final durationMin = (route['duration'] / 60).round();

          setState(() {
            _routePoints = points;
            _markers = [
              Marker(
                point: start,
                width: 40,
                height: 40,
                child: const Icon(Icons.my_location, color: Colors.blue, size: 32),
              ),
              Marker(
                point: end,
                width: 40,
                height: 40,
                child: const Icon(Icons.location_on, color: Colors.red, size: 40),
              ),
            ];
          });

          _mapController.fitCamera(
            CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(points),
              padding: const EdgeInsets.all(50),
            ),
          );

          await _speak('$label is $distanceKm kilometers away. It will take about $durationMin minutes.');
        } else {
          await _speak('Sorry, I could not find a route to $label');
        }
      }
    } catch (e) {
      await _speak('Sorry, something went wrong while finding the route');
    }
  }

  Future<void> _searchNearby(String key, String value, String label) async {
    setState(() => _isBusy = true);
    await _speak('Searching for nearby $label');
    try {
      final query = '''
[out:json];
node["$key"="$value"](around:5000,${_currentLocation.latitude},${_currentLocation.longitude});
out body 15;
''';
      final url = Uri.parse('https://overpass-api.de/api/interpreter');
      final res = await http.post(url, body: {'data': query});
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final elements = data['elements'] as List;
        if (elements.isNotEmpty) {
          setState(() {
            _markers = elements.map<Marker>((e) {
              return Marker(
                point: LatLng(e['lat'], e['lon']),
                width: 40,
                height: 40,
                child: const Icon(Icons.place, color: Colors.deepPurple, size: 32),
              );
            }).toList();
            _markers.add(Marker(
              point: _currentLocation,
              width: 40,
              height: 40,
              child: const Icon(Icons.my_location, color: Colors.blue, size: 32),
            ));
            _routePoints = [];
          });
          await _speak('Found ${elements.length} $label nearby');
        } else {
          await _speak('Sorry, no $label found nearby');
        }
      }
    } catch (e) {
      await _speak('Sorry, something went wrong while searching');
    }
    setState(() => _isBusy = false);
  }

  Future<void> _onSearchSubmitted(String value) async {
    if (value.trim().isEmpty) return;
    await _processCommand(value.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation,
              initialZoom: 6,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.jawg.io/jawg-streets/{z}/{x}/{y}.png?access-token=QFNRzV07NaXkJGqiAUXAvAwlMLTwhcNx6u5HK40oHNI3YXShaUH4gRnaCkSl20oH'
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.example.voice_nav_app',
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(points: _routePoints, strokeWidth: 5, color: Colors.blueAccent),
                  ],
                ),
              MarkerLayer(markers: _markers),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(30),
                      child: TextField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        onSubmitted: _onSearchSubmitted,
                        decoration: InputDecoration(
                          hintText: 'Search: "Chishtian to Lahore" or "restaurant"',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.send),
                            onPressed: () => _onSearchSubmitted(_searchController.text),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    elevation: 4,
                    shape: const CircleBorder(),
                    child: PopupMenuButton<String>(
                      icon: const Icon(Icons.language),
                      onSelected: (val) => setState(() => _selectedLocale = val),
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'en_US', child: Text('English')),
                        PopupMenuItem(value: 'ur_PK', child: Text('Urdu')),
                        PopupMenuItem(value: 'ar_SA', child: Text('Arabic')),
                        PopupMenuItem(value: 'fr_FR', child: Text('Français')),
                        PopupMenuItem(value: 'es_ES', child: Text('Español')),
                        PopupMenuItem(value: 'hi_IN', child: Text('Hindi')),
                        PopupMenuItem(value: 'zh_CN', child: Text('Chinese')),
                        PopupMenuItem(value: 'tr_TR', child: Text('Turkish')),
                        PopupMenuItem(value: 'fa_IR', child: Text('Persian')),
                        PopupMenuItem(value: 'ru_RU', child: Text('Russian')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isBusy)
            const Positioned(
              top: 80,
              left: 0,
              right: 0,
              child: Center(child: CircularProgressIndicator()),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 130,
                    width: 130,
                    child: Lottie.asset(
                      'assets/avatar.json',
                      animate: _isListening,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.smart_toy, size: 60, color: Colors.deepPurple);
                      },
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 30),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _text,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
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
