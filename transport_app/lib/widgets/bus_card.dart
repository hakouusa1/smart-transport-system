import 'dart:async';
import 'dart:math' show cos, pi;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:latlong2/latlong.dart';
import '../models/bus_model.dart';
import '../app_config.dart' as config;
import '../screens/bus_tracking_screen.dart';
import '../services/route_service.dart';
import '../services/location_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../theme_notifier.dart';
import 'pulsing_dot.dart';



class BusCard extends StatelessWidget {
  final Bus bus;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleStatus;

  const BusCard({
    super.key,
    required this.bus,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    final isTrip = bus.driverStatus == 'on_trip';
    final isOnline = bus.driverStatus == 'online';
    final statusColor = isTrip ? context.appGreen : isOnline ? context.appPurple : context.appSub;
    final statusText = isTrip ? 'En trajet' : isOnline ? 'En ligne' : 'Hors ligne';
    final date = '${bus.createdAt.day.toString().padLeft(2, '0')}/${bus.createdAt.month.toString().padLeft(2, '0')}/${bus.createdAt.year}';

    return Container(
      margin: EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: context.appCardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          // ── Top section: Route ──
          Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              children: [
                // Route header: city names
                Row(
                  children: [
                    Expanded(
                      child: Text(bus.displayLineName.split('-').first.trim(),
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.appDark)),
                    ),
                    Icon(Icons.arrow_forward, size: 14, color: context.appSub),
                    Expanded(
                      child: Text(
                          bus.displayLineName.contains('-') ? bus.displayLineName.split('-').last.trim() : '',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.appDark),
                          textAlign: TextAlign.end),
                    ),
                  ],
                ),
                SizedBox(height: 10),

                RouteThumbnail(
                  bus: bus,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BusTrackingScreen(bus: bus))),
                ),
                SizedBox(height: 8),

                // Bus name + number
                Row(
                  children: [
                    if (bus.busName.isNotEmpty)
                      Text(bus.busName, style: TextStyle(fontSize: 12, color: context.appSub)),
                    if (bus.busName.isNotEmpty && bus.busNumber.isNotEmpty)
                      Text('  ·  ', style: TextStyle(color: context.appSub, fontSize: 10)),
                    if (bus.busNumber.isNotEmpty)
                      Text('N° ${bus.busNumber}', style: TextStyle(fontSize: 12, color: context.appSub)),
                    const Spacer(),
                    Text(date, style: TextStyle(fontSize: 11, color: context.appSub)),
                  ],
                ),
              ],
            ),
          ),

          // ── Divider with cutouts ──
          Row(
            children: [
              Container(width: 14, height: 14, decoration: BoxDecoration(
                  color: context.appBg, shape: BoxShape.circle)),
              Expanded(child: Container(height: 1,
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: context.appBorder, width: 1, style: BorderStyle.solid))))),
              Container(width: 14, height: 14, decoration: BoxDecoration(
                  color: context.appBg, shape: BoxShape.circle)),
            ],
          ),

          // ── Bottom section: Status + Actions ──
          Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Column(
              children: [
                // Tags row
                Row(
                  children: [
                    // Active/Inactive tag
                    _Tag(bus.isActive ? 'Actif' : 'Inactif', bus.isActive ? context.appGreen : context.appOrange),
                    SizedBox(width: 6),
                    // Driver status tag
                    isTrip
                        ? const _LiveStatusTag()
                        : _Tag(statusText, statusColor),
                    const Spacer(),
                    // Passenger count
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('bookings')
                          .where('busId', isEqualTo: bus.busId)
                          .where('status', whereIn: ['pending', 'confirmed']).snapshots(),
                      builder: (_, snap) {
                        final count = snap.data?.docs.length ?? 0;
                        if (count == 0) return SizedBox();
                        return Row(children: [
                          Icon(Icons.people, size: 14, color: context.appPurple),
                          SizedBox(width: 4),
                          Text('$count', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.appPurple)),
                        ]);
                      },
                    ),
                  ],
                ),
                SizedBox(height: 12),

                // Action buttons
                Row(
                  children: [
                    // Toggle status
                    Expanded(
                      child: _ActionBtn(
                        icon: bus.isActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        label: bus.isActive ? 'Désactiver' : 'Activer',
                        color: bus.isActive ? context.appOrange : context.appGreen,
                        onTap: onToggleStatus,
                      ),
                    ),
                    SizedBox(width: 8),
                    // Edit
                    _IconBtn(Icons.edit_outlined, context.appPurple, onEdit),
                    SizedBox(width: 6),
                    // Delete
                    _IconBtn(Icons.delete_outline, context.appRed, onDelete),
                  ],
                ),
              ],
            ),
                  ),
                ],
              ),
    );
  }
}

class RouteThumbnail extends StatefulWidget {
  final Bus bus;
  final VoidCallback? onTap;
  final double height;

  const RouteThumbnail({super.key, required this.bus, this.onTap, this.height = 130});

  @override
  State<RouteThumbnail> createState() => _RouteThumbnailState();
}

class _RouteThumbnailState extends State<RouteThumbnail> {
  final LocationService _locationService = LocationService();
  StreamSubscription<BusLocation?>? _busLocationSub;

  List<LatLng> _routePoints = [];
  BusLocation? _busLocation;
  bool _routeLoaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.bus.driverStatus == 'on_trip') {
      _loadRoute();
      _startListeningBusLocation();
    }
  }

  @override
  void didUpdateWidget(RouteThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bus.driverStatus != widget.bus.driverStatus) {
      if (widget.bus.driverStatus == 'on_trip') {
        _loadRoute();
        _startListeningBusLocation();
      } else {
        _busLocationSub?.cancel();
        _busLocationSub = null;
        if (mounted) {
          setState(() {
            _routePoints = [];
            _busLocation = null;
            _routeLoaded = false;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _busLocationSub?.cancel();
    super.dispose();
  }

  Future<void> _loadRoute() async {
    if (!widget.bus.hasDeparture || !widget.bus.hasArrival) return;

    final from = LatLng(widget.bus.departureLat!, widget.bus.departureLng!);
    final to = LatLng(widget.bus.arrivalLat!, widget.bus.arrivalLng!);

    final result = await RouteService.getRoute(from, to);
    if (mounted && result != null && result.points.isNotEmpty) {
      setState(() {
        _routePoints = result.points;
        _routeLoaded = true;
      });
    }
  }

  void _startListeningBusLocation() {
    _busLocationSub?.cancel();
    _busLocationSub = _locationService
        .getBusLocationStream(widget.bus.busId)
        .listen((location) {
          if (mounted) {
            setState(() => _busLocation = location);
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final double finalWidth = width.isFinite && width > 0 ? width : 300;
        return _buildContent(context, finalWidth);
      },
    );
  }

  Widget _buildContent(BuildContext context, double width) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fallbackColor = isDark ? const Color(0xFF1a2535) : const Color(0xFFd8e8f5);

    if (!widget.bus.hasDeparture || !widget.bus.hasArrival) {
      return _fallback(context, fallbackColor);
    }

    final dep = LatLng(widget.bus.departureLat!, widget.bus.departureLng!);
    final arr = LatLng(widget.bus.arrivalLat!, widget.bus.arrivalLng!);

    if (!config.useMapbox) {
      return _buildOsmThumbnail(context, dep, arr);
    }

    // Calculate center including bus location if available
    final List<LatLng> pointsForCenter = [dep, arr];
    if (widget.bus.driverStatus == 'on_trip' && _busLocation != null) {
      pointsForCenter.add(_busLocation!.latLng);
    }

    final centerLat = pointsForCenter.map((p) => p.latitude).reduce((a, b) => a + b) / pointsForCenter.length;
    final centerLng = pointsForCenter.map((p) => p.longitude).reduce((a, b) => a + b) / pointsForCenter.length;

    // Calculate dynamic padding based on route distance
    // Rough distance calculation using lat/lng differences (approximate km)
    final latDiff = (dep.latitude - arr.latitude).abs();
    final lngDiff = (dep.longitude - arr.longitude).abs();
    final roughDistance = (latDiff * 111 + lngDiff * 111 * cos(dep.latitude * pi / 180)).abs();
    final dynamicPadding = roughDistance > 500 ? 60.0 : roughDistance > 200 ? 40.0 : roughDistance > 50 ? 25.0 : 15.0;

    // Build Mapbox static URL with bus marker if available
    String staticUrl;
    if (widget.bus.driverStatus == 'on_trip' && _busLocation != null) {
      // Custom URL with bus marker
      final w = (width * 2).toInt().clamp(1, 1280);
      final h = (widget.height * 2).toInt().clamp(1, 1280);
      final style = isDark ? 'dark-v11' : 'streets-v12';

      final depMarker = 'pin-s-a+00D265(${dep.longitude},${dep.latitude})';
      final arrMarker = 'pin-s-b+F40000(${arr.longitude},${arr.latitude})';
      final busColor = 'FF8B00'; // Orange color for bus marker
      final busMarker = 'pin-s-bus+$busColor(${_busLocation!.longitude},${_busLocation!.latitude})';

      staticUrl = 'https://api.mapbox.com/styles/v1/mapbox/$style/static/$depMarker,$arrMarker,$busMarker/auto/${w}x$h?access_token=${config.mapboxToken}&padding=${dynamicPadding.toInt()}';
    } else {
      staticUrl = RouteService.getStaticMapUrl(
        lat: centerLat,
        lng: centerLng,
        width: width,
        height: widget.height,
        departure: dep,
        arrival: arr,
        isDark: isDark,
        padding: dynamicPadding.toInt(),
      );
    }
    
    if (widget.bus.driverStatus == 'on_trip' && _busLocation != null) {
      // Custom URL with bus marker
      final w = (width * 2).toInt().clamp(1, 1280);
      final h = (widget.height * 2).toInt().clamp(1, 1280);
      final style = isDark ? 'dark-v11' : 'streets-v12';

      final depMarker = 'pin-s-a+00D265(${dep.longitude},${dep.latitude})';
      final arrMarker = 'pin-s-b+F40000(${arr.longitude},${arr.latitude})';
      final busColor = 'FF8B00'; // Orange color for bus marker
      final busMarker = 'pin-s-bus+$busColor(${_busLocation!.longitude},${_busLocation!.latitude})';

      staticUrl = 'https://api.mapbox.com/styles/v1/mapbox/$style/static/$depMarker,$arrMarker,$busMarker/auto/${w}x$h?access_token=${config.mapboxToken}&padding=15';
    } else {
      staticUrl = RouteService.getStaticMapUrl(
        lat: centerLat,
        lng: centerLng,
        width: width,
        height: widget.height,
        departure: dep,
        arrival: arr,
        isDark: isDark,
      );
    }

    Widget imageMap = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: widget.height,
        width: width,
        child: Stack(
          children: [
            // Base background
            Container(color: fallbackColor),

            // Cached static map from Mapbox
            CachedNetworkImage(
              imageUrl: staticUrl,
              width: width,
        height: widget.height,
              fit: BoxFit.cover,
              placeholder: (context, url) => Shimmer.fromColors(
                baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
                child: Container(
                  width: width,
        height: widget.height,
                  color: Colors.white,
                ),
              ),
              errorWidget: (context, url, error) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.directions_bus, size: 32, color: context.appSub.withValues(alpha: 0.5)),
                    const SizedBox(height: 4),
                    Text('Carte indisponible', style: TextStyle(fontSize: 10, color: context.appSub)),
                  ],
                ),
              ),
            ),

            if (widget.bus.driverStatus != 'on_trip')
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    return widget.onTap != null ? GestureDetector(behavior: HitTestBehavior.opaque, onTap: () {
      HapticFeedback.selectionClick();
      widget.onTap!();
    }, child: imageMap) : imageMap;
  }

  Widget _buildOsmThumbnail(BuildContext context, LatLng dep, LatLng arr) {
    // Calculate map bounds to include route and bus location
    final List<LatLng> allPoints = [dep, arr];
    if (_routeLoaded && _routePoints.isNotEmpty) {
      allPoints.addAll(_routePoints.where((point) =>
        point != dep && point != arr && (_busLocation == null || point != _busLocation!.latLng)
      ));
    }
    if (_busLocation != null) {
      allPoints.add(_busLocation!.latLng);
    }

    // Calculate dynamic padding based on route distance for optimal zoom
    // Rough distance calculation using lat/lng differences (approximate km)
    final latDiff = (dep.latitude - arr.latitude).abs();
    final lngDiff = (dep.longitude - arr.longitude).abs();
    final roughDistance = (latDiff * 111 + lngDiff * 111 * cos(dep.latitude.abs() * pi / 180)).abs();
    final dynamicPadding = roughDistance > 500 ? 60.0 : roughDistance > 200 ? 40.0 : roughDistance > 50 ? 25.0 : 15.0;

    Widget mapWidget = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            AbsorbPointer(
              child: FlutterMap(
                options: MapOptions(
                  initialCameraFit: CameraFit.coordinates(
                    coordinates: allPoints,
                    padding: EdgeInsets.all(dynamicPadding),
                  ),
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: RouteService.tileUrl,
                    userAgentPackageName: 'com.example.transporteur_app',
                    tileSize: config.mapTileSize,
                    zoomOffset: config.mapZoomOffset,
                  ),
                  // Show actual route if loaded, otherwise straight line
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routeLoaded && _routePoints.isNotEmpty ? _routePoints : [dep, arr],
                        color: context.appPrimary,
                        strokeWidth: 3.0,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      // Departure marker
                      Marker(
                        point: dep,
                        width: 14,
                        height: 14,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF00D265),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                      // Arrival marker
                      Marker(
                        point: arr,
                        width: 14,
                        height: 14,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF40000),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                      // Bus location marker (only for buses on trip)
                      if (widget.bus.driverStatus == 'on_trip' && _busLocation != null)
                        Marker(
                          point: _busLocation!.latLng,
                          width: 20,
                          height: 20,
                          child: Container(
                            decoration: BoxDecoration(
                              color: context.appOrange,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.directions_bus,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (widget.bus.driverStatus != 'on_trip')
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Row(mainAxisSize: MainAxisSize.min, children: const [
                      Icon(Icons.location_off_outlined, color: Colors.white70, size: 16),
                      SizedBox(width: 6),
                      Text('Pas en trajet', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
                    ]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    return widget.onTap != null
        ? GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              widget.onTap!();
            },
            child: mapWidget,
          )
        : mapWidget;
  }

  Widget _fallback(BuildContext context, Color fallbackColor) {
    Widget map = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: widget.height,
        color: fallbackColor,
        child: Center(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: context.appGreen, shape: BoxShape.circle)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(children: List.generate(6, (_) => Container(
                width: 5, height: 2, margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(color: context.appSub.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(1)),
              ))),
            ),
            Container(width: 10, height: 10, decoration: BoxDecoration(color: context.appRed, shape: BoxShape.circle)),
          ]),
        ),
      ),
    );

    return widget.onTap != null ? GestureDetector(behavior: HitTestBehavior.opaque, onTap: () {
      HapticFeedback.selectionClick();
      widget.onTap!();
    }, child: map) : map;
  }
}

class _Tag extends StatelessWidget {
  final String label; final Color color;
  const _Tag(this.label, this.color);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: color.withValues(alpha: 0.06),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _LiveStatusTag extends StatefulWidget {
  const _LiveStatusTag();

  @override
  State<_LiveStatusTag> createState() => _LiveStatusTagState();
}

class _LiveStatusTagState extends State<_LiveStatusTag> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: context.appGreen.withValues(alpha: 0.06),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PulsingDot(color: context.appGreen, size: 6),
          SizedBox(width: 4),
          Text(
            'En trajet',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: context.appGreen),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appCardBg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 40,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: color, size: 18),
            SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ]),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon; final Color color; final VoidCallback onTap;
  const _IconBtn(this.icon, this.color, this.onTap);
  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }
}