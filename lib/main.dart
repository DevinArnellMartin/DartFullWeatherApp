import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'nwsAccess.dart';
import 'effects.dart';
import 'alerts.dart';
import 'dart:io';

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

  runApp(const WeatherApp());
}

class WeatherApp extends StatefulWidget {
  const WeatherApp({super.key});

  @override
  State<WeatherApp> createState() => WeatherState();
}

class WeatherState extends State<WeatherApp> {
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

  bool showAlerts = true;
  List<dynamic> sevenDayForecast = []; 
  List<Marker> markers = [];  

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    loadWeatherData();
    fetchMessages();
  }

  Future<void> loadWeatherData() async {
    Future.delayed(const Duration(seconds: 30), () {
      fetchWeather();
      fetch7DayForecast();
    });
  }

  void toggleWeatherAlertsVisibility() {
    setState(() {
      showAlerts = !showAlerts;  
    });
  }
  
  Future<void> fetchWeather() async {
    final nwsService = NWSWeatherService();
    final String apiKey = dotenv.env['WEATHER_API_KEY']!;
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
        updateWeatherTheme(weatherData['description'] ?? 'Undefined');
        return;
      }
    }
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
      updateWeatherTheme(weatherData['description'] ?? 'Undefined');
    } else {
      print('Error fetching weather: ${response.statusCode}');
    }
  }

  Future<void> fetch7DayForecast() async {
    final apiKey = dotenv.env['WEATHER_API_KEY']!;
    final response = await http.get(Uri.parse(
      'https://api.openweathermap.org/data/2.5/onecall?lat=${userPos.latitude}&lon=${userPos.longitude}&appid=$apiKey'
    ));

    if (response.statusCode == 200) {
      final forecastData = json.decode(response.body);
      setState(() {
        sevenDayForecast = forecastData['daily']; 
      });
    } else {
      print('Error forecast: ${response.statusCode}');
    }
  }

  void updateWeatherTheme(String weatherCondition) {
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

  Future<void> fetchMessages() async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final snapshot = await firestore.collection('messages').get();
    setState(() {
      markers = snapshot.docs.map((doc) {
        final data = doc.data();
        return Marker(
          markerId: MarkerId(doc.id),
          position: LatLng(data['latitude'], data['longitude']),
          infoWindow: InfoWindow(title: data['message']),
        );
      }).toList();
    });
  }

  Future<void> sendMessage(String message, PickedFile? image) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final String messageId = firestore.collection('messages').doc().id;
    String? imageUrl;

    if (image != null) {
      final firebaseStorageRef = FirebaseStorage.instance.ref().child('images/$messageId');
      await firebaseStorageRef.putFile(File(image.path));
      imageUrl = await firebaseStorageRef.getDownloadURL();
    }

    await firestore.collection('messages').doc(messageId).set({
      'message': message,
      'latitude': userPos.latitude,
      'longitude': userPos.longitude,
      'imageUrl': imageUrl ?? '',
    });

    fetchMessages();
  }

  Future<void> pickImage() async {
    final PickedFile? image = await _picker.getImage(source: ImageSource.gallery);
    if (image != null) {
      sendMessage("See what the world is saying", image);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weatherly'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
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
                Expanded(
                  child: ListView.builder(
                    itemCount: sevenDayForecast.length,
                    itemBuilder: (context, index) {
                      final day = sevenDayForecast[index];
                      return ListTile(
                        title: Text('Day ${index + 1}: ${day['weather'][0]['description']}'),
                        subtitle: Text('Temp: ${day['temp']['day']}°C'),
                      );
                    },
                  ),
                ),
                ElevatedButton(
                  onPressed: toggleWeatherAlertsVisibility,
                  child: const Text('Toggle Weather Alerts'),
                ),
                ElevatedButton(
                  onPressed: pickImage,
                  child: const Text('Pick Image and Send'),
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
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(40.7128, -74.0060),
          zoom: 10,
        ),
        markers: Set<Marker>.of([]),
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
      body: Column(
        children: [
          ElevatedButton(
            onPressed: () {
              updateTheme(ThemeMode.dark); 
            },
            child: const Text('Switch to Dark Theme'),
          ),
          ElevatedButton(
            onPressed: () {
              updateTheme(ThemeMode.light);
            },
            child: const Text('Switch to Light Theme'),
          ),
        ],
      ),
    );
  }
}
