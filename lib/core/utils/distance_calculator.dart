import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DistanceCalculator {
  // haversine formula for calculating distance between two points
  static double calculateHaversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // earth's radius in kilometers

    // convert degrees to radians
    double lat1Rad = lat1 * (pi / 180);
    double lon1Rad = lon1 * (pi / 180);
    double lat2Rad = lat2 * (pi / 180);
    double lon2Rad = lon2 * (pi / 180);

    // differences
    double dLat = lat2Rad - lat1Rad;
    double dLon = lon2Rad - lon1Rad;

    // haversine formula
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  // using openrouteservice api for more accurate driving distance
  static Future<double?> calculateDrivingDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) async {
    try {
      await dotenv.load(fileName: ".env");
      final apiKey = dotenv.env['OPENROUTESERVICE_API_KEY'];

      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('OPENROUTESERVICE_API_KEY not found in .env file');
      }

      final url = Uri.parse(
          'https://api.openrouteservice.org/v2/directions/driving-car?'
          'api_key=$apiKey&'
          'start=$lon1,$lat1&'
          'end=$lon2,$lat2');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final distance =
            data['features'][0]['properties']['segments'][0]['distance'];
        return distance / 1000; // convert meters to kilometers
      } else {
        print('api request failed: ${response.statusCode}');
        // fallback to haversine calculation
        return calculateHaversineDistance(lat1, lon1, lat2, lon2);
      }
    } catch (e) {
      print('error calculating driving distance: $e');
      // fallback to haversine calculation
      return calculateHaversineDistance(lat1, lon1, lat2, lon2);
    }
  }

  // alternative using google maps distance matrix api (more accurate but requires billing)
  static Future<double?> calculateGoogleMapsDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) async {
    try {
      const String apiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

      final url =
          Uri.parse('https://maps.googleapis.com/maps/api/distancematrix/json?'
              'origins=$lat1,$lon1&'
              'destinations=$lat2,$lon2&'
              'units=metric&'
              'key=$apiKey');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final distanceText = data['rows'][0]['elements'][0]['distance']['text'];
        final distanceValue =
            data['rows'][0]['elements'][0]['distance']['value'];
        return distanceValue / 1000; // convert meters to kilometers
      } else {
        print('google maps api request failed: ${response.statusCode}');
        return calculateHaversineDistance(lat1, lon1, lat2, lon2);
      }
    } catch (e) {
      print('error calculating google maps distance: $e');
      return calculateHaversineDistance(lat1, lon1, lat2, lon2);
    }
  }

  // main method that tries api first, falls back to haversine
  static Future<double?> calculateDistance(
    double? lat1,
    double? lon1,
    double? lat2,
    double? lon2, {
    bool useApi = true,
  }) async {
    // check if all coordinates are available
    if (lat1 == null || lon1 == null || lat2 == null || lon2 == null) {
      return null;
    }

    if (useApi) {
      // try api calculation first
      final apiDistance =
          await calculateDrivingDistance(lat1, lon1, lat2, lon2);
      if (apiDistance != null) {
        return apiDistance;
      }
    }

    // fallback to haversine calculation
    return calculateHaversineDistance(lat1, lon1, lat2, lon2);
  }

  // format distance for display
  static String formatDistance(double? distance) {
    if (distance == null) return 'n/a';

    if (distance < 1) {
      return '${(distance * 1000).round()} m';
    } else {
      return '${distance.toStringAsFixed(1)} km';
    }
  }
}
