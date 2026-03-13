import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../services/route_service.dart';

const _gBlue = Color(0xFF4285F4);
const _gDark = Color(0xFF202124);
const _gSub = Color(0xFF5F6368);
const _gBorder = Color(0xFFDADCE0);

class PickOnMapScreen extends StatefulWidget {
  final String title; // "Point de départ" or "Point d'arrivée"
  final Color pinColor;

  const PickOnMapScreen({super.key, required this.title, required this.pinColor});

  @override
  State<PickOnMapScreen> createState() => _PickOnMapScreenState();
}

class _PickOnMapScreenState extends State<PickOnMapScreen> {
  final MapController _mapController = MapController();
  LatLng? _selectedPoint;
  LatLng? _myPosition;
  bool _loading = true;

  final _defaultCenter = const LatLng(36.7538, 3.0588);

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() => _loading = false);
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        setState(() => _loading = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (mounted) {
        setState(() {
          _myPosition = LatLng(pos.latitude, pos.longitude);
          _loading = false;
        });
        _mapController.move(_myPosition!, 14);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _confirm() {
    if (_selectedPoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Appuyez sur la carte pour choisir un point'),
          backgroundColor: Colors.orange.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }
    Navigator.pop(context, {
      'latitude': _selectedPoint!.latitude,
      'longitude': _selectedPoint!.longitude,
    });
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final center = _myPosition ?? _defaultCenter;

    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _gBlue, strokeWidth: 2.5))
          : Stack(
              children: [
                // Map
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: _myPosition != null ? 14 : 12,
                    onTap: (_, point) {
                      setState(() => _selectedPoint = point);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: RouteService.tileUrl,
                      userAgentPackageName: 'com.example.voyageur_app',
                      tileSize: 512,
                      zoomOffset: -1,
                    ),
                    MarkerLayer(
                      markers: [
                        // My position
                        if (_myPosition != null)
                          Marker(
                            point: _myPosition!, width: 22, height: 22,
                            child: Container(
                              decoration: BoxDecoration(
                                color: _gBlue, shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2.5),
                                boxShadow: [BoxShadow(color: _gBlue.withValues(alpha: 0.3), blurRadius: 8)],
                              ),
                            ),
                          ),
                        // Selected point
                        if (_selectedPoint != null)
                          Marker(
                            point: _selectedPoint!, width: 40, height: 50,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.location_on, color: widget.pinColor, size: 40),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                // Top bar
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: Container(
                    padding: EdgeInsets.fromLTRB(8, top + 8, 16, 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: Row(
                      children: [
                        Material(
                          color: Colors.white, shape: const CircleBorder(), elevation: 2, shadowColor: Colors.black26,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => Navigator.pop(context),
                            child: const Padding(padding: EdgeInsets.all(10), child: Icon(Icons.arrow_back, size: 22, color: _gDark)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(width: 10, height: 10,
                          decoration: BoxDecoration(color: widget.pinColor, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: _gDark)),
                        ),
                      ],
                    ),
                  ),
                ),

                // Hint
                if (_selectedPoint == null)
                  Positioned(
                    bottom: 100, left: 20, right: 20,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
                      ),
                      child: Row(children: [
                        Icon(Icons.touch_app, color: _gBlue, size: 20),
                        const SizedBox(width: 10),
                        const Expanded(child: Text('Appuyez sur la carte pour choisir le point',
                          style: TextStyle(fontSize: 13, color: _gSub))),
                      ]),
                    ),
                  ),

                // Confirm button
                if (_selectedPoint != null)
                  Positioned(
                    bottom: 30, left: 20, right: 20,
                    child: Material(
                      color: _gBlue, borderRadius: BorderRadius.circular(14), elevation: 3,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: _confirm,
                        child: Container(
                          height: 52,
                          alignment: Alignment.center,
                          child: const Text('Confirmer ce point', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                        ),
                      ),
                    ),
                  ),

                // My location button
                if (_myPosition != null)
                  Positioned(
                    bottom: _selectedPoint != null ? 95 : 30, right: 16,
                    child: Material(
                      color: Colors.white, shape: const CircleBorder(), elevation: 2, shadowColor: Colors.black26,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _mapController.move(_myPosition!, 16),
                        child: const Padding(padding: EdgeInsets.all(11), child: Icon(Icons.my_location, size: 22, color: _gBlue)),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
