import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import '../app_config.dart' as config;
import '../services/route_service.dart';
import '../theme_notifier.dart';
import '../widgets/bus_loading_indicator.dart';


class PickLocationScreen extends StatefulWidget {
  final String title;
  final double? initialLat;
  final double? initialLng;

  const PickLocationScreen({
    super.key,
    required this.title,
    this.initialLat,
    this.initialLng,
  });

  @override
  State<PickLocationScreen> createState() => _PickLocationScreenState();
}

class _PickLocationScreenState extends State<PickLocationScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  LatLng? _selectedPoint;
  List<_SearchResult> _searchResults = [];
  bool _isSearching = false;
  bool _showResults = false;

  final LatLng _defaultCenter = const LatLng(36.7538, 3.0588);

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _selectedPoint = LatLng(widget.initialLat!, widget.initialLng!);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================
  // SEARCH USING MAPBOX
  // ============================================
  Future<void> _searchPlace(String query) async {
    if (query.trim().length < 2) {
      setState(() {
        _searchResults = [];
        _showResults = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final url = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/${Uri.encodeComponent(query)}.json'
            '?access_token=${config.mapboxToken}'
            '&country=dz'
            '&language=fr'
            '&limit=5'
            '&types=place,locality,neighborhood,address,poi',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final features = json.decode(response.body)['features'] as List;
        setState(() {
          _searchResults = features.map((f) {
            final coords = f['geometry']['coordinates'] as List;
            return _SearchResult(
              name: f['place_name'] ?? f['text'] ?? '',
              lat: (coords[1] as num).toDouble(),
              lng: (coords[0] as num).toDouble(),
            );
          }).toList();
          _showResults = _searchResults.isNotEmpty;
        });
      }
    } catch (e) {
      // Search failed silently
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectSearchResult(_SearchResult result) {
    final point = LatLng(result.lat, result.lng);
    setState(() {
      _selectedPoint = point;
      _showResults = false;
      _searchController.text = result.shortName;
    });
    _mapController.move(point, 15);
  }

  void _confirm() {
    if (_selectedPoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Veuillez choisir un point sur la carte.'),
          backgroundColor: Colors.orange.shade600,
          behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    Navigator.pop(context, {
      'latitude': _selectedPoint!.latitude,
      'longitude': _selectedPoint!.longitude,
    });
  }

  @override
  Widget build(BuildContext context) {
    final center = _selectedPoint ?? _defaultCenter;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton.icon(
            onPressed: _confirm,
            icon: Icon(Icons.check, color: Colors.white),
            label: Text(
              'Confirmer',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // ============================================
          // MAP
          // ============================================
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: _selectedPoint != null ? 15 : 12,
              onTap: (tapPosition, point) {
                setState(() {
                  _selectedPoint = point;
                  _showResults = false;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: RouteService.tileUrl,
                userAgentPackageName: 'com.example.transporteur_app',
                tileSize: config.mapTileSize,
                zoomOffset: config.mapZoomOffset,
              ),
              if (_selectedPoint != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedPoint!,
                      width: 50,
                      height: 50,
                      child: Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 50,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // ============================================
          // SEARCH BAR + RESULTS
          // ============================================
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Column(
              children: [
                // Search bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _searchPlace,
                    onTap: () {
                      if (_searchResults.isNotEmpty) {
                        setState(() => _showResults = true);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Rechercher un lieu...',
                      prefixIcon: Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults = [];
                            _showResults = false;
                          });
                        },
                      )
                          : _isSearching
                          ? Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: BusLoadingIndicator(strokeWidth: 2),
                        ),
                      )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),

                // Search results dropdown
                if (_showResults && _searchResults.isNotEmpty)
                  Container(
                    margin: EdgeInsets.only(top: 4),
                    constraints: const BoxConstraints(maxHeight: 250),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.symmetric(vertical: 4),
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: Colors.grey.shade200,
                      ),
                      itemBuilder: (context, index) {
                        final result = _searchResults[index];
                        return ListTile(
                          leading: Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.location_on,
                              color: Colors.blue,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            result.shortName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            result.name,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 11,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          dense: true,
                          onTap: () => _selectSearchResult(result),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // ============================================
          // INSTRUCTION
          // ============================================
          if (!_showResults && _selectedPoint == null)
            Positioned(
              bottom: 80,
              left: 20,
              right: 20,
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.touch_app, color: Colors.blue.shade700, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Recherchez un lieu ou appuyez sur la carte',
                        style: TextStyle(color: Colors.blue.shade800, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ============================================
          // SELECTED POINT INFO
          // ============================================
          if (_selectedPoint != null)
            Positioned(
              bottom: 20,
              left: 12,
              right: 12,
              child: Container(
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_pin, color: Colors.red, size: 24),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '${_selectedPoint!.latitude.toStringAsFixed(5)}, ${_selectedPoint!.longitude.toStringAsFixed(5)}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _confirm,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(100, 40),
                      ),
                      child: Text('Confirmer'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchResult {
  final String name;
  final double lat;
  final double lng;

  _SearchResult({required this.name, required this.lat, required this.lng});

  String get shortName {
    final parts = name.split(',');
    if (parts.length >= 2) {
      return '${parts[0].trim()}, ${parts[1].trim()}';
    }
    return name;
  }
}