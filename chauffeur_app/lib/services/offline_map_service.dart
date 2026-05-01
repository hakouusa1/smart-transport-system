import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:latlong2/latlong.dart';
import '../app_config.dart' as config;

class OfflineMapService {
  static const String _storeName = 'route_tiles';
  static bool _initialized = false;
  static bool _downloadComplete = false;
  static FMTCStore? _store;

  /// Initialize the tile cache store
  static Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      await FMTCObjectBoxBackend().initialise();
      _store = FMTCStore(_storeName);
      _initialized = true;
      debugPrint('OfflineMapService: Store initialized');
    } catch (e) {
      debugPrint('OfflineMapService: Failed to initialize: $e');
    }
  }

  /// Check if tiles are cached
  static Future<bool> hasCachedTiles() async {
    if (!_initialized || _store == null) return false;
    
    try {
      final stats = await _store!.stats.all;
      return stats.hits > 0;
    } catch (e) {
      return false;
    }
  }

  /// Get the tile layer with caching provider (automatic caching)
  /// Tiles are cached automatically as they're loaded from the network
  static TileLayer getTileLayer() {
    if (!_initialized || _store == null) {
      // Return online tiles if not initialized
      return _getOnlineTileLayer();
    }
    
    // Return tile layer with caching provider
    // This automatically caches tiles as they're loaded
    return TileLayer(
      urlTemplate: config.mapTileUrl,
      userAgentPackageName: 'com.example.chauffeur_app',
      tileProvider: _store!.getTileProvider(),
      tileSize: config.mapTileSize,
      zoomOffset: config.mapZoomOffset,
    );
  }

  /// Get online-only tile layer
  static TileLayer _getOnlineTileLayer() {
    return TileLayer(
      urlTemplate: config.mapTileUrl,
      userAgentPackageName: 'com.example.chauffeur_app',
      tileSize: config.mapTileSize,
      zoomOffset: config.mapZoomOffset,
    );
  }

  /// Get cache stats
  static Future<Map<String, dynamic>> getCacheStats() async {
    if (!_initialized || _store == null) {
      return {'cached': 0, 'size': 0, 'isReady': false};
    }
    
    try {
      final stats = await _store!.stats.all;
      return {
        'cached': stats.hits,
        'size': stats.size.toInt(),
        'isReady': _initialized,
      };
    } catch (e) {
      return {'cached': 0, 'size': 0, 'isReady': false};
    }
  }

  /// Clear all cached tiles
  static Future<void> clearCache() async {
    if (!_initialized || _store == null) return;
    
    try {
      await _store!.manage.reset();
      debugPrint('OfflineMapService: Cache cleared');
    } catch (e) {
      debugPrint('OfflineMapService: Failed to clear cache: $e');
    }
  }

  /// Cache tiles for a route between two points (explicit pre-caching)
  static Future<void> cacheRouteArea({
    required LatLng departure,
    required LatLng arrival,
    Function(double)? onProgress,
  }) async {
    if (!_initialized || _store == null) {
      debugPrint('OfflineMapService: Not initialized');
      return;
    }

    // Calculate center and radius
    final centerLat = (departure.latitude + arrival.latitude) / 2;
    final centerLng = (departure.longitude + arrival.longitude) / 2;
    
    const dist = Distance();
    final distanceKm = dist.as(LengthUnit.Kilometer, departure, arrival);
    final radiusKm = (distanceKm / 2) * 1.3; // 30% padding
    
    debugPrint('OfflineMapService: Caching route area: center=($centerLat, $centerLng), radius=$radiusKm km');
    
    // Use the cacheArea method with the calculated parameters
    await cacheArea(
      centerLat: centerLat,
      centerLng: centerLng,
      radiusKm: radiusKm,
      minZoom: 10,
      maxZoom: 16,
      onProgress: onProgress,
    );
  }

  /// Pre-cache tiles for a specific area using the downloadable API
  static Future<bool> cacheArea({
    required double centerLat,
    required double centerLng,
    required double radiusKm,
    required int minZoom,
    required int maxZoom,
    Function(double)? onProgress,
  }) async {
    if (!_initialized || _store == null) {
      debugPrint('OfflineMapService: Not initialized');
      return false;
    }

    try {
      debugPrint('OfflineMapService: Starting to cache area at $centerLat, $centerLng with radius $radiusKm km');
      
      // Create a circle region
      final region = CircleRegion(
        LatLng(centerLat, centerLng),
        radiusKm * 1000, // Convert km to meters
      );
      
      // Convert to downloadable region
      final downloadableRegion = region.toDownloadable(
        minZoom: minZoom,
        maxZoom: maxZoom,
        options: TileLayer(
          urlTemplate: config.mapTileUrl,
          userAgentPackageName: 'com.example.chauffeur_app',
          tileSize: config.mapTileSize,
          zoomOffset: config.mapZoomOffset,
        ),
      );
      
      // Start the download - use startForeground which returns a DownloadTask
      final downloadTask = _store!.download.startForeground(
        region: downloadableRegion,
        parallelThreads: 5,
        maxBufferLength: 200,
      );
      
      // Process the download progress stream
      await for (final progress in downloadTask.downloadProgress) {
        final percentage = progress.percentageProgress / 100.0;
        onProgress?.call(percentage);
        debugPrint('OfflineMapService: Caching progress: ${progress.percentageProgress.toStringAsFixed(1)}%');
      }
      
      _downloadComplete = true;
      debugPrint('OfflineMapService: Area cached successfully');
      return true;
    } catch (e) {
      debugPrint('OfflineMapService: Failed to cache area: $e');
      return false;
    }
  }

  /// Check if service is initialized
  static bool get isReady => _initialized && _store != null;
  
  /// Check if download is complete
  static bool get isDownloadComplete => _downloadComplete;
}
