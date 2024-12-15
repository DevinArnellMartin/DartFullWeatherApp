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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

//api_key == key for weather API, apiKey = key for Firebase




void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: dotenv.env['WEATHER_API_KEY']!,
      authDomain: dotenv.env['AUTH_DOMAIN']!,
      projectId: dotenv.env['PROJECT_ID']!,
      storageBucket: dotenv.env['STORAGE_BUCKET']!,
      messagingSenderId: dotenv.env['MESSAGING_SENDER_ID']!,
      appId: dotenv.env['APP_ID']!,
    ),
  );
  runApp(const WeatherlyApp());
}

class WeatherlyApp extends StatefulWidget {
  const WeatherlyApp({super.key});

  @override
  State<WeatherlyApp> createState() => _WeatherlyAppState();
}

class _WeatherlyAppState extends State<WeatherlyApp> {
  ThemeMode theme = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    load();
  }

   Future<void> load() async { //TODO CHECK!
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String storedTheme = prefs.getString('theme') ?? 'light'; 
    setState(() {
      theme = storedTheme == 'dark' ? ThemeMode.dark : ThemeMode.light; 
    });
  }


 
  void updateTheme(ThemeMode themeMode) {
    setState(() {
      theme = themeMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weatherly',
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: theme,
      routes: {
        '/': (context) => HomeScreen(updateTheme: updateTheme),
        '/settings': (context) => SettingsScreen(updateTheme: updateTheme),
        '/map': (context) => const MapScreen(),
      },
    );
  }
}

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Radar'),
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
/*
class _SettingsScreenState extends State<SettingsScreen> {
  bool hideAlerts = false;
  String theme = 'Light';
  final List<String> themes = ['Light', 'Dark', 'Verbose'];
  File? customBackground;
 Future<void> pickImage() async {
    // Image Picker code (e.g., use `image_picker` package)
    // Mock implementation
    // File pickedImage = await ImagePicker().pickImage(source: ImageSource.gallery);
    // setState(() { customBackground = pickedImage; });

    }
*/
class HomeScreen extends StatefulWidget {
  final Function(ThemeMode) updateTheme;

  const HomeScreen({super.key, required this.updateTheme});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String city = 'New York';
  Map<String, dynamic>? weatherData;
  Position? userPos;

  @override
  void initState() {
    super.initState();
    getCurrentLocation();
  }

  Future<void> getCurrentLocation() async {
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
    String api_Key = dotenv.env['WEATHER_API_KEY']!;
    final url = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?q=$city&appid=$api_Key');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      setState(() {
        weatherData = json.decode(response.body);
      });
      updateThemeBasedOnWeather(weatherData!['weather'][0]['main']);
    }
  }


  void updateThemeBasedOnWeather(String weatherCondition) {
    ThemeMode newTheme;
    switch (weatherCondition.toLowerCase()) {
      //TODO (?) Make more background interactive in theme
      case 'clear':
        newTheme = ThemeMode.light;
        break;
      case 'rain':
      case 'thunderstorm':
      case 'drizzle':
        newTheme = ThemeMode.dark;
        break;
      default:
        newTheme = ThemeMode.light;
    }
    widget.updateTheme(newTheme);
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
                Text(weatherData!['weather'][0]['main']),
                ElevatedButton(
                  onPressed: fetchWeather,
                  child: const Text('Refresh'),
                ),
              ],
            ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  final Function(ThemeMode) updateTheme;

  const SettingsScreen({super.key, required this.updateTheme});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedTheme = 'light';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedTheme = prefs.getString('theme') ?? 'light';
    });
  }

  Future<void> save(String theme) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', theme);
    ThemeMode themeMode = theme == 'dark' ? ThemeMode.dark : ThemeMode.light;
    widget.updateTheme(themeMode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Column(
        children: [
          ListTile(
            title: const Text('Default'),
            trailing: DropdownButton<String>(
              value: _selectedTheme,
              items: const [
                DropdownMenuItem(value: 'light', child: Text('Light Theme')),
                DropdownMenuItem(value: 'dark', child: Text('Dark Theme')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedTheme = value!;
                });
                save(value!);
              },
            ),
          ),
        ],
      ),
    );
  }
}
