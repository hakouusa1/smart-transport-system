import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../app_config.dart' as config;

class GeocodeResult {
  final double lat;
  final double lng;
  final String resolvedName;

  GeocodeResult({required this.lat, required this.lng, required this.resolvedName});
}

class GeocodingException implements Exception {
  final String reason;
  GeocodingException(this.reason);
  @override
  String toString() => reason;
}

class GeocodingService {
  /// Resolves a free-text place name to lat/lng, biased to Algeria.
  /// Throws [GeocodingException] with a specific reason on failure,
  /// or returns null when no place matches the query.
  static Future<GeocodeResult?> geocodeInAlgeria(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      throw GeocodingException('Le nom est vide.');
    }
    if (!config.hasMapbox) {
      throw GeocodingException(
          'Token Mapbox manquant. Lancez l\'app avec --dart-define=MAPBOX_TOKEN=...');
    }

    final url = Uri.parse(
      'https://api.mapbox.com/geocoding/v5/mapbox.places/${Uri.encodeComponent(trimmed)}.json'
      '?access_token=${config.mapboxToken}'
      '&country=dz'
      '&language=fr'
      '&limit=1',
    );

    http.Response res;
    try {
      res = await http.get(url);
    } catch (e) {
      debugPrint('[Geocoding] HTTP error: $e');
      throw GeocodingException(
          'Erreur réseau pendant la géolocalisation: $e');
    }

    if (res.statusCode == 401 || res.statusCode == 403) {
      throw GeocodingException(
          'Token Mapbox invalide ou non autorisé (${res.statusCode}).');
    }
    if (res.statusCode != 200) {
      throw GeocodingException(
          'Réponse inattendue de Mapbox (${res.statusCode}): ${res.body}');
    }

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw GeocodingException('Réponse Mapbox illisible.');
    }

    final features = body['features'] as List?;
    if (features == null || features.isEmpty) return null;

    final feat = features.first as Map<String, dynamic>;
    final center = feat['center'] as List?;
    if (center == null || center.length < 2) {
      throw GeocodingException('Coordonnées absentes dans la réponse.');
    }

    final lng = (center[0] as num).toDouble();
    final lat = (center[1] as num).toDouble();
    final resolvedName = (feat['place_name'] as String?) ?? trimmed;

    return GeocodeResult(lat: lat, lng: lng, resolvedName: resolvedName);
  }
}
