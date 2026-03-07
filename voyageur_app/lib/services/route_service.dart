import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

const mapboxToken =
    'pk.eyJ1IjoiaGFrb3UwODgiLCJhIjoiY21tZXgxMTJvMDF5eDJyc2hxY2Y3OW1rOCJ9.v74bMi9y79UmP4ixwsuLJw';

class RouteResult {
  final List<LatLng> points;
  final double durationSeconds;
  final double distanceMeters;

  RouteResult({
    required this.points,
    required this.durationSeconds,
    required this.distanceMeters,
  });

  int get etaMinutes => (durationSeconds / 60).round();

  double get distanceKm => distanceMeters / 1000;

  String get etaText {
    final min = etaMinutes;
    if (min < 1) return 'Arrivée imminente';
    if (min == 1) return '1 minute';
    if (min < 60) return '$min min';
    return '${min ~/ 60}h ${min % 60}min';
  }

  String get distanceText {
    if (distanceMeters < 1000) {
      return '${distanceMeters.toStringAsFixed(0)} m';
    }
    return '${distanceKm.toStringAsFixed(1)} km';
  }
}

class RouteService {
  /// Mapbox tile URL - light style
  static String get tileUrl =>
      'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/{z}/{x}/{y}@2x?access_token=$mapboxToken';

  /// Mapbox tile URL - dark style (modern)
  static String get darkTileUrl =>
      'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/{z}/{x}/{y}@2x?access_token=$mapboxToken';

  /// Mapbox tile URL - navigation style (clear roads)
  static String get navTileUrl =>
      'https://api.mapbox.com/styles/v1/mapbox/navigation-day-v1/tiles/{z}/{x}/{y}@2x?access_token=$mapboxToken';

  /// Get route from Mapbox: points + duration + distance
  /// Uses steps=true for detailed geometry following every road curve
  static Future<RouteResult?> getRoute(LatLng from, LatLng to) async {
    try {
      final url = Uri.parse(
        'https://api.mapbox.com/directions/v5/mapbox/driving/'
            '${from.longitude},${from.latitude};'
            '${to.longitude},${to.latitude}'
            '?overview=false&steps=true&geometries=geojson&access_token=$mapboxToken',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'] as List<dynamic>?;

        if (routes != null && routes.isNotEmpty) {
          final route = routes[0];

          final duration = (route['duration'] as num?)?.toDouble() ?? 0;
          final distance = (route['distance'] as num?)?.toDouble() ?? 0;

          // Collect ALL step geometries for maximum detail
          final List<LatLng> allPoints = [];
          final legs = route['legs'] as List<dynamic>?;

          if (legs != null) {
            for (final leg in legs) {
              final steps = leg['steps'] as List<dynamic>?;
              if (steps != null) {
                for (final step in steps) {
                  final coords =
                  step['geometry']['coordinates'] as List<dynamic>;
                  for (final c in coords) {
                    final point = LatLng(
                      (c[1] as num).toDouble(),
                      (c[0] as num).toDouble(),
                    );
                    if (allPoints.isEmpty || allPoints.last != point) {
                      allPoints.add(point);
                    }
                  }
                }
              }
            }
          }

          if (allPoints.isNotEmpty) {
            return RouteResult(
              points: allPoints,
              durationSeconds: duration,
              distanceMeters: distance,
            );
          }
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }
}