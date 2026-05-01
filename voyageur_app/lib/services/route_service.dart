import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../app_config.dart' as config;
import '../data/algeria_stops.dart';

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
    if (distanceMeters < 1000) return '${distanceMeters.toStringAsFixed(0)} m';
    return '${distanceKm.toStringAsFixed(1)} km';
  }
}

class RouteService {
  /// Map tile URL
  static String get tileUrl => config.mapTileUrl;

  static final Map<String, _CachedRoute> _cache = {};

  static String _key(LatLng a, LatLng b) =>
      '${a.latitude.toStringAsFixed(4)},${a.longitude.toStringAsFixed(4)}'
      '->${b.latitude.toStringAsFixed(4)},${b.longitude.toStringAsFixed(4)}';

  /// Get route from Mapbox with FULL road-following geometry
  /// overview=full returns every curve and turn on the road
  static Future<RouteResult?> getRoute(LatLng from, LatLng to) async {
    final key = _key(from, to);
    final hit = _cache[key];
    if (hit != null && !hit.isExpired) return hit.result;

    try {
      final url = Uri.parse(config.getDirectionsUrl(from.longitude, from.latitude, to.longitude, to.latitude));

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'] as List<dynamic>?;

        if (routes != null && routes.isNotEmpty) {
          final route = routes[0];
          final duration = (route['duration'] as num?)?.toDouble() ?? 0;
          final distance = (route['distance'] as num?)?.toDouble() ?? 0;

          // overview=full gives the complete geometry in route['geometry']
          final coords = route['geometry']['coordinates'] as List<dynamic>;
          final points = <LatLng>[];

          for (final c in coords) {
            points.add(LatLng(
              (c[1] as num).toDouble(),
              (c[0] as num).toDouble(),
            ));
          }

          if (points.isNotEmpty) {
            final result = RouteResult(
              points: points,
              durationSeconds: duration,
              distanceMeters: distance,
            );
            _cache[key] = _CachedRoute(result);
            return result;
          }
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }
}

class _CachedRoute {
  final RouteResult result;
  final DateTime _at;
  _CachedRoute(this.result) : _at = DateTime.now();
  bool get isExpired => DateTime.now().difference(_at).inMinutes >= 10;
}

// ── Route stop model ───────────────────────────────────────────────────────

class RouteStop {
  final String name;
  final double lat;
  final double lng;

  /// Index of the closest point on the full route polyline.
  final int routeIndex;

  const RouteStop({
    required this.name,
    required this.lat,
    required this.lng,
    required this.routeIndex,
  });

  LatLng get latLng => LatLng(lat, lng);
}

// ── Stop detection ─────────────────────────────────────────────────────────

extension StopDetection on RouteService {
  /// Normalise a place name for fuzzy matching:
  /// lowercase + strip French diacritics + collapse punctuation to spaces.
  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[àâä]'), 'a')
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[îï]'), 'i')
      .replaceAll(RegExp(r'[ôö]'), 'o')
      .replaceAll(RegExp(r'[ùûü]'), 'u')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r"['\-]"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Resolves admin-entered stop names (plain strings, possibly with
  /// typographic variants) to [RouteStop] objects positioned on [routePoints].
  ///
  /// Matching strategy (in priority order):
  ///  1. Exact normalised match  ("Lakhdaria" == "Lakhdaria")
  ///  2. One name starts with the other  ("Ain Bessam" ≈ "Aïn Bessam")
  ///  3. One name contains the other
  static List<RouteStop> resolveAdminStops({
    required List<String> stopNames,
    required List<LatLng> routePoints,
    required double departureLat,
    required double departureLng,
    required double arrivalLat,
    required double arrivalLng,
  }) {
    if (stopNames.isEmpty || routePoints.isEmpty) return [];

    const d = Distance();
    final departure = LatLng(departureLat, departureLng);
    final arrival = LatLng(arrivalLat, arrivalLng);
    final result = <RouteStop>[];

    for (final rawName in stopNames) {
      final name = rawName.trim();
      if (name.isEmpty) continue;
      final nName = _norm(name);

      // Lookup in the database (fuzzy, 3-tier)
      AlgeriaStop? matched;
      for (final s in kAlgeriaStops) {
        if (_norm(s.name) == nName) { matched = s; break; }
      }
      if (matched == null) {
        for (final s in kAlgeriaStops) {
          final ns = _norm(s.name);
          if (ns.startsWith(nName) || nName.startsWith(ns)) { matched = s; break; }
        }
      }
      if (matched == null) {
        for (final s in kAlgeriaStops) {
          final ns = _norm(s.name);
          if (ns.contains(nName) || nName.contains(ns)) { matched = s; break; }
        }
      }

      // If still not found, keep the name but can't place it on the map
      if (matched == null) continue;

      final pt = LatLng(matched.lat, matched.lng);

      // Skip if too close to departure or arrival (8 km)
      if (d.as(LengthUnit.Meter, pt, departure) < 8000) continue;
      if (d.as(LengthUnit.Meter, pt, arrival) < 8000) continue;

      // Find closest point on the route polyline
      double minDist = double.infinity;
      int bestIdx = -1;
      for (int i = 0; i < routePoints.length; i++) {
        final v = d.as(LengthUnit.Meter, pt, routePoints[i]);
        if (v < minDist) { minDist = v; bestIdx = i; }
      }

      if (bestIdx >= 0 && bestIdx > 2 && bestIdx < routePoints.length - 3) {
        result.add(RouteStop(
          name: matched.name, // canonical name from the database
          lat: matched.lat,
          lng: matched.lng,
          routeIndex: bestIdx,
        ));
      }
    }

    // Sort by position along the route
    result.sort((a, b) => a.routeIndex.compareTo(b.routeIndex));
    return result;
  }
}