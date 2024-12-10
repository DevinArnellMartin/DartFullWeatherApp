import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const WeatherlyApp());
}

class WeatherlyApp extends StatelessWidget {
  const WeatherlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weatherly',
      routes: {
        '/': (context) => const HomeScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/map': (context) => const MapScreen(),
      },
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeScreen(),
    );
  }
}

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weather Radar'),
      ),
      body: const GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(40.7128, -74.0060),
          zoom: 10,
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String apiKey = String.fromEnvironment('WEATHER_API_KEY');
  String city = 'New York';
  Map<String, dynamic>? weatherData;
  Map<String, dynamic>? alertsData;
  Position? userPos;

  @override
  void initState() {
    super.initState();
    getCurrentLocation();
  }

  Future<void> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      showSnackbar('Location services are disabled.');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        showSnackbar('Location permissions are denied.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      showSnackbar('Location permissions are permanently denied.');
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    userPos = position;

    List<Placemark> placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );
    setState(() {
      city = placemarks[0].locality ?? 'Unknown';
    });

    fetchWeather();
  }

  Future<void> fetchWeather() async {
    final url = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?q=$city&appid=$apiKey');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      setState(() {
        weatherData = json.decode(response.body);
      });
    } else {
      throw Exception('Failed to fetch weather data.');
    }
  }

  Future<void> fetchAlerts() async {
    if (userPos == null) return;

    String state = await getStateFromCoordinates(
        userPos!.latitude, userPos!.longitude);
    final url = Uri.parse(
        'https://api.weather.gov/alerts/active?area=$state');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      setState(() {
        alertsData = json.decode(response.body);
      });
      showAlertsDialog();
    } else {
      throw Exception('Failed to fetch alerts.');
    }
  }

  Future<String> getStateFromCoordinates(double lat, double lon) async {
    List<Placemark> placemarks = await placemarkFromCoordinates(lat, lon);
    return placemarks.first.administrativeArea ?? '';
  }

  void showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void showAlertsDialog() {
    if (alertsData == null || alertsData!['features'].isEmpty) {
      showSnackbar('No immenient alerts ');
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Weather Alerts'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: alertsData!['features'].length,
              itemBuilder: (context, index) {
                var alert = alertsData!['features'][index]['properties'];
                return ListTile(
                  title: Text(alert['headline'] ?? 'No Title'),
                  subtitle: Text(alert['description'] ?? 'No Description'),
                );
              },
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weatherly'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: fetchAlerts,
          ),
        ],
      ),
      body: weatherData == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Current Weather:$city',
                  style: const TextStyle(fontSize: 24),
                ),
                Text(
                  '${(weatherData!['main']['temp'] - 273.15).toStringAsFixed(1)}°C',
                  style: const TextStyle(fontSize: 32),
                ),
                Text(weatherData!['weather'][0]['description']),
                ElevatedButton(
                  onPressed: fetchWeather,
                  child: const Text('Refresh'),
                ),
              ],
            ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: const Center(
        child: Text('Settings Screen'),
      ),
    );
  }
}
