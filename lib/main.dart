import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'google.dart';

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
      routes:{
        '/': (context) => const HomeScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/map': (context) => const MapScreen(),
      },
      theme: ThemeData(primarySwatch: Colors.blue),
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
  String apiKey = 'API_KEY'; //TODO Add env 
  String city = 'New York';
  Map<String, dynamic>? weatherData;

  Future<void> fetchWeather() async {
    final url = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?q=$city&appid=$apiKey');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      setState(() {
        weatherData = json.decode(response.body);
      });
    } else {
      throw Exception('Failed to fetch');
    }
  }

  @override
  void initState() {
    super.initState();
    fetchWeather();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weatherly'),
      ),
      body: weatherData == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Current Weather in $city',
                  style: const TextStyle(fontSize: 24),
                ),
                Text(
                  '${(weatherData!['main']['temp'] - 273.15).toStringAsFixed(1)}°C',
                  style: const TextStyle(fontSize: 32),
                ),
                Text(weatherData!['weather'][0]['description']),
                ElevatedButton(
                  onPressed: () => fetchWeather(),
                  child: const Text('Refresh'),
                ),
              ],
            ),
    );
  }
}


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  String favoriteCity = '';

  Future<void> savePreference() async {
    await firestore.collection('preferences').doc('user1').set({
      'favorite_city': favoriteCity,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Favorite City'),
              onChanged: (value) {
                favoriteCity = value;
              },
            ),
            ElevatedButton(
              onPressed: savePreference,
              child: const Text('Save Preferences'),
            ),
          ],
        ),
      ),
    );
  }
}

class NotificationsManager {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  void initNotifications() {
    _firebaseMessaging.requestPermission();
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        print('Notification Title: ${message.notification!.title}');
        print('Notification Body: ${message.notification!.body}');
      }
    });
  }

  Future<void> sendTestNotification() async {
    await _firebaseMessaging.subscribeToTopic('weather_alerts');
  }
}


