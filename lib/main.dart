import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'nwsAccess.dart';
import 'effects.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: dotenv.env['API_KEY']!,
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
    loadTheme();
  }

  Future<void> loadTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String storedTheme = prefs.getString('theme') ?? 'light';
    setState(() {
      theme = storedTheme == 'dark' ? ThemeMode.dark : ThemeMode.light;
    });
  }

  void updateTheme(ThemeMode themeMode) async {
    setState(() {
      theme = themeMode;
    });
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', themeMode == ThemeMode.dark ? 'dark' : 'light');
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

class HomeScreen extends StatefulWidget {
  final Function(ThemeMode) updateTheme;

  const HomeScreen({super.key, required this.updateTheme});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String city = 'New York';  
  Map<String, dynamic> weatherData = {};
  Position userPos = Position(
    latitude: 37.7749, 
    longitude: -122.4194,
    timestamp: DateTime.now(),
    accuracy: 0.0,
    altitude: 0.0,
    speed: 0.0,
    speedAccuracy: 0.0,
    headingAccuracy: 0.0,
    altitudeAccuracy: 0.0,
    heading: 0.0
  ); 

  @override
  void initState() {
    super.initState();
    loadWeatherData();
  }

  Future<void> loadWeatherData() async {
    // You can delay the call to get the current location here
    Future.delayed(const Duration(seconds: 30), () {
      fetchWeather(); // Call after 30 seconds
    });
  }

  Future<void> fetchWeather() async {
    // Fetch the weather based on the current location
    final nwsService = NWSWeatherService();
    final String apiKey = dotenv.env['WEATHER_API_KEY']!;

    // Assuming userPos is valid, no need to check for null values here
    final stationUrl = await nwsService.getNearestStationUrl(
      userPos.latitude,
      userPos.longitude,
    );
    if (stationUrl != null) {
      final observation = await nwsService.getObservation(stationUrl);
      if (observation != null) {
        setState(() {
          weatherData = {
            'pressure': observation.pressure,
            'humidity': observation.humidity,
            'description': observation.description,
          };
        });
        updateThemeBasedOnWeather(weatherData['description'] ?? 'Unknown');
        return;
      }
    }

    // Fallback to OpenWeather if NWS data is not available
    final response = await http.get(Uri.parse(
      'https://api.openweathermap.org/data/2.5/weather?q=$city&appid=$apiKey'));
    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);
      setState(() {
        weatherData = {
          'pressure': responseData['main']?['pressure'] ?? 'N/A',
          'humidity': responseData['main']?['humidity'] ?? 'N/A',
          'description': responseData['weather']?[0]?['main'] ?? 'N/A',
        };
      });
      updateThemeBasedOnWeather(weatherData['description'] ?? 'Unknown');
    } else {
      print('Error fetching weather data: ${response.statusCode}');
    }
  }

  void updateThemeBasedOnWeather(String weatherCondition) {
    ThemeMode newTheme;
    Widget weatherEffect = const SizedBox(); 
    switch (weatherCondition.toLowerCase()) {
      case 'clear':
        newTheme = ThemeMode.light;
        break;
      case 'rain':
      case 'thunderstorm':
        newTheme = ThemeMode.dark;
        weatherEffect = Rain();
        break;
      case 'drizzle':
        newTheme = ThemeMode.dark;
        weatherEffect = Drizzle();
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
      body: weatherData.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Current Weather in $city',
                  style: const TextStyle(fontSize: 24),
                ),
                Text(
                  weatherData['description'] ?? 'No Data',
                  style: const TextStyle(fontSize: 18),
                ),
                Text(
                  'Pressure: ${weatherData['pressure']} hPa',
                  style: const TextStyle(fontSize: 18),
                ),
                Text(
                  'Humidity: ${weatherData['humidity']}%',
                  style: const TextStyle(fontSize: 18),
                ),
              ],
            ),
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

class SettingsScreen extends StatelessWidget {
  final Function(ThemeMode) updateTheme;

  const SettingsScreen({super.key, required this.updateTheme});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            updateTheme(ThemeMode.dark); 
          },
          child: const Text('Switch Theme'),
        ),
      ),
    );
  }
}