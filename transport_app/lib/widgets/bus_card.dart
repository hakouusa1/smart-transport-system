import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/bus_model.dart';
import '../screens/bus_tracking_screen.dart';
import '../services/route_service.dart';
import '../services/route_service.dart';
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
                      child: Text(bus.lineName.split('-').first.trim(),
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.appDark)),
                    ),
                    Icon(Icons.arrow_forward, size: 14, color: context.appSub),
                    Expanded(
                      child: Text(
                          bus.lineName.contains('-') ? bus.lineName.split('-').last.trim() : '',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.appDark),
                          textAlign: TextAlign.end),
                    ),
                  ],
                ),
                SizedBox(height: 10),

                // Map thumbnail — only tappable when bus is en trajet
                RouteThumbnail(
                  bus: bus,
                  onTap: isTrip
                      ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => BusTrackingScreen(bus: bus)))
                      : null,
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
  RouteThumbnail({required this.bus, this.onTap, this.height = 130});

  @override
  State<RouteThumbnail> createState() => _RouteThumbnailState();
}

class _RouteThumbnailState extends State<RouteThumbnail> {
  List<LatLng> _routePoints = [];
  bool _routeLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  Future<void> _loadRoute() async {
    if (!widget.bus.hasDeparture || !widget.bus.hasArrival) return;

    try {
      final from = LatLng(widget.bus.departureLat!, widget.bus.departureLng!);
      final to = LatLng(widget.bus.arrivalLat!, widget.bus.arrivalLng!);

      final result = await RouteService.getRoute(from, to);

      if (mounted && result != null && result.points.isNotEmpty) {
        setState(() {
          _routePoints = result.points;
          _routeLoaded = true;
        });
      }
    } catch (e) {
      // Ignore errors, keep straight line
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!widget.bus.hasDeparture || !widget.bus.hasArrival) {
      return _fallback(context, isDark);
    }

    final dep = LatLng(widget.bus.departureLat!, widget.bus.departureLng!);
    final arr = LatLng(widget.bus.arrivalLat!, widget.bus.arrivalLng!);

    // Center & zoom
    LatLng center;
    double zoom;
    if (_routeLoaded && _routePoints.isNotEmpty) {
      final bounds = LatLngBounds.fromPoints(_routePoints);
      center = LatLng((bounds.north + bounds.south) / 2, (bounds.east + bounds.west) / 2);
      final latDiff = bounds.north - bounds.south;
      final lngDiff = bounds.east - bounds.west;
      final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;
      zoom = (maxDiff < 0.05 ? 13.0
          : maxDiff < 0.2  ? 11.0
          : maxDiff < 0.8  ? 9.0
          : maxDiff < 2.0  ? 8.0
          : maxDiff < 4.0  ? 7.0
          : 6.0) - 0.5;
    } else {
      final centerLat = (dep.latitude + arr.latitude) / 2;
      final centerLng = (dep.longitude + arr.longitude) / 2;
      center = LatLng(centerLat, centerLng);

      final latDiff = (dep.latitude - arr.latitude).abs();
      final lngDiff = (dep.longitude - arr.longitude).abs();
      final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;
      zoom = (maxDiff < 0.05 ? 13.0
          : maxDiff < 0.2  ? 11.0
          : maxDiff < 0.8  ? 9.0
          : maxDiff < 2.0  ? 8.0
          : maxDiff < 4.0  ? 7.0
          : 6.0) - 0.5;
    }

    Widget map = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            // Solid bg so there's never a grey flash
            Container(color: isDark ? const Color(0xFF1a2535) : const Color(0xFFd8e8f5)),

            IgnorePointer(
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: zoom,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.transport.owner',
                    tileBuilder: isDark ? _darkTileBuilder : null,
                  ),
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routeLoaded ? _routePoints : [dep, arr],
                        color: context.appGreen,
                        strokeWidth: 3.5,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: dep,
                        width: 20, height: 20,
                        child: Icon(Icons.location_on, color: context.appGreen, size: 20),
                      ),
                      Marker(
                        point: arr,
                        width: 20, height: 20,
                        child: Icon(Icons.location_on, color: context.appRed, size: 20),
                      ),
                      if (widget.bus.driverStatus == 'on_trip')
                        Marker(
                          point: dep,
                          width: 24, height: 24,
                          child: Icon(Icons.directions_bus, color: context.appPrimary, size: 20),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            if (widget.bus.driverStatus != 'on_trip')
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.35),
                  child: Center(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
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

    return widget.onTap != null ? GestureDetector(onTap: widget.onTap, child: map) : map;
  }

  Widget _fallback(BuildContext context, bool isDark) {
    Widget map = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: widget.height,
        color: isDark ? const Color(0xFF1a2535) : const Color(0xFFd8e8f5),
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

    return widget.onTap != null ? GestureDetector(onTap: widget.onTap, child: map) : map;
  }

  Widget _darkTileBuilder(BuildContext context, Widget tile, TileImage tileImage) {
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        -0.8, 0, 0, 0, 255,
         0, -0.8, 0, 0, 255,
         0, 0, -0.8, 0, 255,
         0, 0, 0, 1, 0,
      ]),
      child: tile,
    );
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
        onTap: onTap,
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
        onTap: onTap,
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