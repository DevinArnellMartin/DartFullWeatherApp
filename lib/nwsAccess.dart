import 'package:http/http.dart' as http;
import 'dart:convert';

class Observation {
  final double pressure;
  final double humidity;
  final String description;

  const Observation({
    required this.pressure,
    required this.humidity,
    required this.description,
  });

  String format() {
    return 'Pressure: ${pressure.toStringAsFixed(2)} hPa\n'
        'Humidity: ${humidity.toStringAsFixed(0)}%\n'
        'Description: $description';
  }
}

class NWSWeatherService {
  static const String NWSURL = "https://api.weather.gov";
  static const Map<String, String> headers = {
    "Accept": "application/geo+json",
    "User-Agent": "Wealthly (https://github.com/DevinArnellMartin/DartFullWeatherApp)"
  };

  Future<String?> getNearestStationUrl(double latitude, double longitude) async {
    final url = Uri.parse('$NWSURL/points/$latitude,$longitude/stations');
    final res = await http.get(url, headers: headers);

    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      if (data['observationStations'] != null && data['observationStations'].isNotEmpty) {
        return data['observationStations'][0];
      }
    }
    return null; 
  }

  Future<Observation?> getObservation(String stationUrl) async {
    final url = Uri.parse('$stationUrl/observations/latest');
    final res = await http.get(url, headers: headers);

    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      final properties = data['properties'];
      if (properties != null) {
        return Observation(
          pressure: ((properties['barometricPressure']?['value'] ?? 0.0) / 100.0),
          humidity: (properties['relativeHumidity']?['value'] ?? 0.0),
          description: properties['textDescription'] ?? 'No description',
        );
      }
    }
    return null; 
  }
}
