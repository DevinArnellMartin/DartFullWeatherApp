import 'package:flutter/material.dart';

class WeatherAlertWidget extends StatelessWidget {
  final List<Map<String, String>> weatherAlerts = [
    {
      'title': 'Severe Thunderstorm Warning',
      'description': 'Heavy wind ,lightining , and rain',
      'severity': 'High',
    },
    {
      'title': 'Flood Watch',
      'description': 'Flood Watch',
      'severity': 'Moderate',
    },
    {
      'title': 'Heat Advisory',
      'description': 'Heats expected to exceed 100 degrees',
      'severity': 'Low',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ListView.builder(
        itemCount: weatherAlerts.length,
        itemBuilder: (context, index) {
          final alert = weatherAlerts[index];
          return Card(
            color: _getSeverityColor(alert['severity']!),
            margin: const EdgeInsets.all(8),
            child: ListTile(
              title: Text(
                alert['title']!,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                alert['description']!,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'High':
        return Colors.red;
      case 'Moderate':
        return Colors.orange;
      case 'Low':
        return Colors.yellow;
      default:
        return Colors.grey;
    }
  }
}