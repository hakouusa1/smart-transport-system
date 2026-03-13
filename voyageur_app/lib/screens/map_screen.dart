import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../models/bus_model.dart';
import '../services/bus_service.dart';
import '../services/location_service.dart';
import '../services/route_service.dart';
import '../services/notification_service.dart';
import '../widgets/booking_button.dart';

const _gBlue = Color(0xFF4285F4);
const _gGreen = Color(0xFF34A853);
const _gRed = Color(0xFFEA4335);
const _gYellow = Color(0xFFFBBC05);
const _gDark = Color(0xFF202124);
const _gText = Color(0xFF3C4043);
const _gSub = Color(0xFF5F6368);
const _gLight = Color(0xFFF1F3F4);
const _gBorder = Color(0xFFDADCE0);

class MapScreen extends StatefulWidget {
  final Bus bus;
  const MapScreen({super.key, required this.bus});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final LocationService _locationService = LocationService();
  final BusService _busService = BusService();
  final MapController _mapController = MapController();

  StreamSubscription<BusLocation?>? _busLocationSub;
  StreamSubscription<Position>? _myPositionSub;
  Timer? _etaRefreshTimer;

  BusLocation? _busLocation;
  LatLng? _myPosition;
  Bus? _currentBus;
  bool _isLoading = true;
  bool _busOffline = false;
  String _lastUpdateTime = '--:--';
  bool _followBus = true;

  int _etaMinutes = 0;
  String _etaText = '--';
  String _distText = '--';
  String _arrText = '--:--';
  String _meToBusText = '--';

  List<LatLng> _fullRoute = [];
  List<LatLng> _doneRoute = [];
  List<LatLng> _leftRoute = [];
  bool _routeOk = false;
  LatLng? _lastEtaPos;

  LatLng? _tapPt;
  String? _tapEta;
  String? _tapDist;
  bool _tapLoading = false;

  late AnimationController _panelAnim;
  late Animation<Offset> _panelSlide;

  // ETA notifications
  bool _notified10min = false;
  bool _notified5min = false;
  bool _notifiedTripStart = false;

  final _center = const LatLng(36.7538, 3.0588);

  @override
  void initState() {
    super.initState();
    _currentBus = widget.bus;
    _panelAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _panelSlide = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _panelAnim, curve: Curves.easeOutCubic));
    _initLocation();
    _listenBus();
    _loadRoute();
    _etaRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchETA());
  }

  @override
  void dispose() {
    _busLocationSub?.cancel();
    _myPositionSub?.cancel();
    _etaRefreshTimer?.cancel();
    _panelAnim.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════
  // LOCATION
  // ═══════════════════════════════════════
  Future<void> _initLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (mounted) {
        setState(() => _myPosition = LatLng(pos.latitude, pos.longitude));
        _calcMeToBus();
      }
      _myPositionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
      ).listen((p) {
        if (mounted) {
          setState(() => _myPosition = LatLng(p.latitude, p.longitude));
          _calcMeToBus();
        }
      });
    } catch (_) {}
  }

  void _calcMeToBus() {
    if (_myPosition == null || _busLocation == null) return;
    final m = const Distance().as(LengthUnit.Meter, _myPosition!, _busLocation!.latLng);
    setState(() => _meToBusText = m < 1000
        ? '${m.toStringAsFixed(0)} m'
        : '${(m / 1000).toStringAsFixed(1)} km');
  }

  // ═══════════════════════════════════════
  // BUS STREAM
  // ═══════════════════════════════════════
  void _listenBus() {
    _busLocationSub = _locationService.getBusLocationStream(widget.bus.busId).listen((loc) {
      if (!mounted) return;

      if (loc == null) {
        setState(() { _busOffline = true; _isLoading = false; });
        return;
      }

      final wasOffline = _busOffline;
      setState(() {
        _busLocation = loc;
        _busOffline = false;
        _isLoading = false;
        _lastUpdateTime = DateFormat('HH:mm').format(DateTime.now());
      });

      // Notify trip started
      if (wasOffline && !_notifiedTripStart) {
        _notifiedTripStart = true;
        NotificationService.showNotification(
          title: '🚌 Trajet démarré',
          body: '${widget.bus.lineName} est en route !',
          id: 10,
        );
      }

      _calcMeToBus();
      _splitRoute();
      if (_needEta()) _fetchETA();
      if (_followBus) _mapController.move(loc.latLng, _mapController.camera.zoom);
      _panelAnim.forward();
    });

    _busService.getBusById(widget.bus.busId).listen((b) {
      if (mounted && b != null) setState(() => _currentBus = b);
    });
  }

  // ═══════════════════════════════════════
  // ROUTE & ETA
  // ═══════════════════════════════════════
  Future<void> _loadRoute() async {
    final b = _currentBus ?? widget.bus;
    if (!b.hasDeparture || !b.hasArrival) return;
    final r = await RouteService.getRoute(
      LatLng(b.departureLat!, b.departureLng!),
      LatLng(b.arrivalLat!, b.arrivalLng!),
    );
    if (mounted && r != null && r.points.isNotEmpty) {
      setState(() {
        _fullRoute = r.points;
        _leftRoute = List.from(r.points);
        _doneRoute = [];
        _routeOk = true;
      });
      _splitRoute();
    }
  }

  Future<void> _fetchETA() async {
    final b = _currentBus ?? widget.bus;
    if (_busLocation == null || !b.hasArrival) return;
    final r = await RouteService.getRoute(
      _busLocation!.latLng,
      LatLng(b.arrivalLat!, b.arrivalLng!),
    );
    if (mounted && r != null) {
      final arr = DateTime.now().add(Duration(seconds: r.durationSeconds.round()));
      setState(() {
        _etaMinutes = r.etaMinutes;
        _etaText = r.etaText;
        _distText = r.distanceText;
        _arrText = DateFormat('HH:mm').format(arr);
        _lastEtaPos = _busLocation!.latLng;
      });
      _checkETANotifications();
    }
  }

  void _checkETANotifications() {
    if (_etaMinutes <= 10 && _etaMinutes > 5 && !_notified10min) {
      _notified10min = true;
      NotificationService.showNotification(
        title: '🚌 Bus arrive dans ~10 min',
        body: '${widget.bus.lineName} — Préparez-vous.',
        id: 11,
      );
    }
    if (_etaMinutes <= 5 && !_notified5min) {
      _notified5min = true;
      NotificationService.showNotification(
        title: '🚌 Bus arrive dans ~5 min !',
        body: '${widget.bus.lineName} est presque là !',
        id: 12,
      );
    }
  }

  void _splitRoute() {
    if (!_routeOk || _fullRoute.isEmpty || _busLocation == null) return;
    double min = double.infinity;
    int idx = 0;
    const d = Distance();
    for (int i = 0; i < _fullRoute.length; i++) {
      final v = d.as(LengthUnit.Meter, _busLocation!.latLng, _fullRoute[i]);
      if (v < min) { min = v; idx = i; }
    }
    setState(() {
      _doneRoute = [..._fullRoute.sublist(0, idx + 1), _busLocation!.latLng];
      _leftRoute = [_busLocation!.latLng, ..._fullRoute.sublist(idx)];
    });
  }

  bool _needEta() => _lastEtaPos == null || _busLocation == null ||
      const Distance().as(LengthUnit.Meter, _lastEtaPos!, _busLocation!.latLng) >= 100;

  // ═══════════════════════════════════════
  // TAP ON ROUTE
  // ═══════════════════════════════════════
  void _onRouteTap(LatLng ll) {
    if (_leftRoute.length < 2 || _busLocation == null) return;
    double min = double.infinity;
    int idx = 0;
    const d = Distance();
    for (int i = 0; i < _leftRoute.length; i++) {
      final v = d.as(LengthUnit.Meter, ll, _leftRoute[i]);
      if (v < min) { min = v; idx = i; }
    }
    if (min > 100) return;
    setState(() {
      _tapPt = _leftRoute[idx];
      _tapEta = null;
      _tapDist = null;
      _tapLoading = true;
    });
    _fetchTapEta(_leftRoute[idx]);
  }

  Future<void> _fetchTapEta(LatLng pt) async {
    if (_busLocation == null) return;
    final r = await RouteService.getRoute(_busLocation!.latLng, pt);
    if (mounted && r != null) {
      setState(() { _tapEta = r.etaText; _tapDist = r.distanceText; _tapLoading = false; });
    } else {
      setState(() { _tapEta = '--'; _tapLoading = false; });
    }
  }

  // ═══════════════════════════════════════
  // CONTROLS
  // ═══════════════════════════════════════
  void _fitAll() {
    final b = _currentBus ?? widget.bus;
    final pts = <LatLng>[];
    if (_myPosition != null) pts.add(_myPosition!);
    if (_busLocation != null) pts.add(_busLocation!.latLng);
    if (b.hasDeparture) pts.add(LatLng(b.departureLat!, b.departureLng!));
    if (b.hasArrival) pts.add(LatLng(b.arrivalLat!, b.arrivalLng!));
    if (pts.length >= 2) {
      _mapController.fitCamera(CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(pts),
        padding: const EdgeInsets.all(80),
      ));
      _followBus = false;
    }
  }

  Color get _etaColor => _etaMinutes <= 5 ? _gGreen : _etaMinutes <= 15 ? _gYellow : _gRed;

  // ═══════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final bus = _currentBus ?? widget.bus;
    final live = _busLocation != null && !_busOffline;
    final top = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: _isLoading
            ? Container(
          color: Colors.white,
          child: const Center(
            child: CircularProgressIndicator(color: _gBlue, strokeWidth: 3),
          ),
        )
            : Stack(
          children: [
            // ═══════════════════════════════════════
            // MAP
            // ═══════════════════════════════════════
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _myPosition ?? (live ? _busLocation!.latLng : _center),
                initialZoom: live ? 14 : 12,
                onTap: (_, ll) {
                  if (_tapPt != null) {
                    if (_leftRoute.length >= 2 && _busLocation != null) {
                      double min = double.infinity;
                      const d = Distance();
                      for (final p in _leftRoute) {
                        final v = d.as(LengthUnit.Meter, ll, p);
                        if (v < min) min = v;
                      }
                      if (min < 60) { _onRouteTap(ll); return; }
                    }
                    setState(() { _tapPt = null; _tapEta = null; _tapDist = null; });
                  } else {
                    _onRouteTap(ll);
                  }
                },
                onPositionChanged: (_, g) { if (g) _followBus = false; },
              ),
              children: [
                TileLayer(
                  urlTemplate: RouteService.tileUrl,
                  userAgentPackageName: 'com.example.voyageur_app',
                  tileSize: 512,
                  zoomOffset: -1,
                ),

                // Done route (grey)
                if (_doneRoute.length >= 2)
                  PolylineLayer(polylines: [
                    Polyline(points: _doneRoute, color: const Color(0xFFBDC1C6), strokeWidth: 12),
                  ]),

                // Remaining route (blue)
                if (_leftRoute.length >= 2)
                  PolylineLayer(polylines: [
                    Polyline(points: _leftRoute, color: _gBlue, strokeWidth: 12),
                  ]),

                // Fallback
                if (!_routeOk && live && bus.hasArrival)
                  PolylineLayer(polylines: [
                    Polyline(
                      points: [_busLocation!.latLng, LatLng(bus.arrivalLat!, bus.arrivalLng!)],
                      color: _gBlue.withValues(alpha: 0.5),
                      strokeWidth: 4,
                    ),
                  ]),

                // Markers
                MarkerLayer(markers: [
                  // Departure
                  if (bus.hasDeparture)
                    Marker(
                      point: LatLng(bus.departureLat!, bus.departureLng!),
                      width: 18, height: 18,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _gGreen,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),

                  // Arrival
                  if (bus.hasArrival)
                    Marker(
                      point: LatLng(bus.arrivalLat!, bus.arrivalLng!),
                      width: 36, height: 42,
                      child: const Icon(Icons.location_on, color: _gRed, size: 42),
                    ),

                  // My position
                  if (_myPosition != null)
                    Marker(
                      point: _myPosition!,
                      width: 22, height: 22,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _gBlue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [BoxShadow(color: _gBlue.withValues(alpha: 0.3), blurRadius: 8)],
                        ),
                      ),
                    ),

                  // Bus
                  if (live)
                    Marker(
                      point: _busLocation!.latLng,
                      width: 40, height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6, offset: const Offset(0, 2))],
                        ),
                        child: Center(
                          child: Container(
                            width: 32, height: 32,
                            decoration: const BoxDecoration(color: _gBlue, shape: BoxShape.circle),
                            child: const Icon(Icons.directions_bus, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ),

                  // Tap popup
                  if (_tapPt != null)
                    Marker(
                      point: _tapPt!,
                      width: 130, height: 56,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 2))],
                            ),
                            child: _tapLoading
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _gBlue))
                                : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_tapEta ?? '--', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _gDark)),
                                if (_tapDist != null) ...[
                                  const Text('  ·  ', style: TextStyle(color: _gSub, fontSize: 10)),
                                  Text(_tapDist!, style: const TextStyle(fontSize: 10, color: _gSub)),
                                ],
                              ],
                            ),
                          ),
                          Container(
                            width: 8, height: 8,
                            margin: const EdgeInsets.only(top: 2),
                            decoration: const BoxDecoration(color: _gBlue, shape: BoxShape.circle),
                          ),
                        ],
                      ),
                    ),
                ]),
              ],
            ),

            // ═══════════════════════════════════════
            // TOP BAR
            // ═══════════════════════════════════════
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(8, top + 8, 16, 8),
                child: Row(
                  children: [
                    Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      elevation: 2,
                      shadowColor: Colors.black26,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => Navigator.pop(context),
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(Icons.arrow_back, size: 22, color: _gText),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        elevation: 2,
                        shadowColor: Colors.black26,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(bus.lineName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: _gDark), overflow: TextOverflow.ellipsis),
                                    if (bus.busName.isNotEmpty)
                                      Text(bus.busName, style: const TextStyle(fontSize: 12, color: _gSub), overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              if (live)
                                Container(
                                  width: 8, height: 8,
                                  margin: const EdgeInsets.only(left: 8),
                                  decoration: const BoxDecoration(color: _gGreen, shape: BoxShape.circle),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ═══════════════════════════════════════
            // OFFLINE BANNER
            // ═══════════════════════════════════════
            if (_busOffline)
              Positioned(
                top: top + 72, left: 16, right: 16,
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  elevation: 1,
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: _gYellow, size: 18),
                        SizedBox(width: 10),
                        Text('Bus pas en trajet actuellement', style: TextStyle(fontSize: 13, color: _gText)),
                      ],
                    ),
                  ),
                ),
              ),

            // ═══════════════════════════════════════
            // ETA HEADER
            // ═══════════════════════════════════════
            if (live && bus.hasArrival)
              Positioned(
                top: top + 72, left: 16, right: 16,
                child: Material(
                  color: _etaColor,
                  borderRadius: BorderRadius.circular(12),
                  elevation: 3,
                  shadowColor: Colors.black26,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_etaText, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white)),
                              const SizedBox(height: 2),
                              Text('$_distText  ·  Arrivée $_arrText',
                                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.9))),
                            ],
                          ),
                        ),
                        if (_myPosition != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.person, color: Colors.white, size: 16),
                                const SizedBox(height: 2),
                                Text(_meToBusText, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

            // ═══════════════════════════════════════
            // BOOKING BUTTON
            // ═══════════════════════════════════════
            if (live && bus.hasArrival)
              Positioned(
                bottom: 175, left: 16, right: 70,
                child: BookingButton(bus: bus, etaMinutes: _etaMinutes),
              ),

            // ═══════════════════════════════════════
            // BOTTOM PANEL
            // ═══════════════════════════════════════
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: SlideTransition(
                position: _panelSlide,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, -2))],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 36, height: 4,
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(color: _gBorder, borderRadius: BorderRadius.circular(2)),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                color: _gBlue.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.directions_bus, color: _gBlue, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    bus.busName.isNotEmpty ? bus.busName : bus.lineName,
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: _gDark),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    bus.busNumber.isNotEmpty ? 'N° ${bus.busNumber}' : bus.statusText,
                                    style: const TextStyle(fontSize: 12, color: _gSub),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: bus.isOnTrip ? _gGreen.withValues(alpha: 0.1) : _gLight,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                bus.statusText,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: bus.isOnTrip ? _gGreen : _gSub,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (live) ...[
                        Divider(height: 1, color: _gBorder, indent: 16, endIndent: 16),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          child: Row(
                            children: [
                              _GStat(Icons.speed, _busLocation!.speedText, 'Vitesse'),
                              Container(width: 1, height: 28, color: _gBorder),
                              _GStat(Icons.update, _lastUpdateTime, 'Mise à jour'),
                            ],
                          ),
                        ),
                      ] else
                        const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),

            // ═══════════════════════════════════════
            // CONTROLS
            // ═══════════════════════════════════════
            Positioned(
              bottom: live ? 200 : 80, right: 16,
              child: Column(
                children: [
                  _GButton(Icons.crop_free, _fitAll),
                  const SizedBox(height: 10),
                  if (live) ...[
                    _GButton(Icons.directions_bus, () {
                      _followBus = true;
                      _mapController.move(_busLocation!.latLng, 16);
                    }),
                    const SizedBox(height: 10),
                  ],
                  if (_myPosition != null)
                    _GButton(Icons.my_location, () {
                      _followBus = false;
                      _mapController.move(_myPosition!, 16);
                    }, tint: _gBlue),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════
// WIDGETS
// ═══════════════════════════════════════
class _GButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? tint;

  const _GButton(this.icon, this.onTap, {this.tint});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Icon(icon, size: 22, color: tint ?? const Color(0xFF5F6368)),
        ),
      ),
    );
  }
}

class _GStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _GStat(this.icon, this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF5F6368)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF202124))),
              Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF5F6368))),
            ],
          ),
        ],
      ),
    );
  }
}