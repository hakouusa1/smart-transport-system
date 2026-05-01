import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../app_config.dart' as config;

const mapboxToken = config.mapboxToken;

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
  /// Map tile URL for flutter_map
  static String get tileUrl => config.mapTileUrl;

  /// Generate a static Mapbox thumbnail URL
  static String getStaticMapUrl({
    required double lat,
    required double lng,
    required double width,
    required double height,
    double zoom = 12.0,
    LatLng? departure,
    LatLng? arrival,
    bool isDark = false,
    int padding = 15,
  }) {
    // Exactly double the UI dimension (retina optimization)
    final w = (width * 2).toInt().clamp(1, 1280);
    final h = (height * 2).toInt().clamp(1, 1280);
    final style = isDark ? 'dark-v11' : 'streets-v12';

    if (departure != null && arrival != null) {
      final depMarker = 'pin-s-a+00D265(${departure.longitude},${departure.latitude})';
      final arrMarker = 'pin-s-b+F40000(${arrival.longitude},${arrival.latitude})';
      // Use auto bounding box for markers
      return 'https://api.mapbox.com/styles/v1/mapbox/$style/static/$depMarker,$arrMarker/auto/${w}x$h?access_token=$mapboxToken&padding=$padding';
    }

    // Fallback to center point
    return 'https://api.mapbox.com/styles/v1/mapbox/$style/static/$lng,$lat,$zoom,0,0/${w}x$h?access_token=$mapboxToken';
  }

  /// Get route from Mapbox: points + duration + distance
  /// Uses steps=true for detailed geometry following every road curve
  static Future<RouteResult?> getRoute(LatLng from, LatLng to) async {
    try {
      final url = Uri.parse(
        config.getDirectionsUrl(from.longitude, from.latitude, to.longitude, to.latitude, steps: true),
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