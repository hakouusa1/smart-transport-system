import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../models/bus_model.dart';
import '../services/bus_service.dart';
import '../services/location_service.dart';
import '../app_config.dart' as config;
import '../services/route_service.dart';
import '../services/notification_service.dart';
import '../models/booking_model.dart';
import '../services/booking_service.dart';
import '../services/booking_monitor_service.dart';
import '../services/booking_foreground_service.dart';
import '../widgets/booking_button.dart';

import '../theme/app_theme.dart';
import '../widgets/bus_loading_indicator.dart';

class MapScreen extends StatefulWidget {
  final Bus bus;
  const MapScreen({super.key, required this.bus});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final LocationService _locationService = LocationService();
  final BusService _busService = BusService();
  final BookingService _bookingService = BookingService();
  final BookingMonitorService _bookingMonitor = BookingMonitorService();
  final MapController _mapController = MapController();

  StreamSubscription<Booking?>? _bookingStatusSub;
  Booking? _myBooking;

  StreamSubscription<BusLocation?>? _busLocationSub;
  StreamSubscription<Position>? _myPositionSub;
  Timer? _etaRefreshTimer;
  Timer? _busToMeEtaTimer;

  BusLocation? _busLocation;
  LatLng? _myPosition;
  Bus? _currentBus;
  bool _busOffline = false;
  String _lastUpdateTime = '--:--';
  bool _followBus = false;

  int _etaMinutes = 0;
  String _etaText = '--';
  String _distText = '--';
  String _arrText = '--:--';
  String _meToBusText = '--';
  String _busToMeEtaText = '--';
  LatLng? _lastBusToMeEtaPos;

  // Progress bar data
  double _totalRouteDistanceMeters = 0;
  double _distanceBusToArrivalMeters = 0;
  String _distanceDepartToBusText = '--';

  List<LatLng> _fullRoute = [];
  List<LatLng> _doneRoute = [];
  List<LatLng> _leftRoute = [];
  List<LatLng> _preRoute = [];
  bool _preRouteLoaded = false;
  bool _routeOk = false;
  LatLng? _lastEtaPos;

  // Intermediate stops
  List<RouteStop> _routeStops = [];
  List<int> _stopETAs = [];
  int _busRouteIdx = -1;
  double _etaDurationSeconds = 0;

  LatLng? _tapPt;
  String? _tapEta;
  String? _tapDist;
  bool _tapLoading = false;

  late AnimationController _moveAnim;
  VoidCallback? _moveAnimListener;

  bool _notified10min = false;
  bool _notified5min = false;
  bool _notifiedTripStart = false;

  // Smooth bus animation
  LatLng? _smoothBusPos;
  LatLng? _prevSmooth;
  late AnimationController _busMotionAnim;

  final _center = const LatLng(36.7538, 3.0588);

  double get _routeProgress {
    if (_totalRouteDistanceMeters <= 0 || _distanceBusToArrivalMeters <= 0) return 0;
    final completed = _totalRouteDistanceMeters - _distanceBusToArrivalMeters;
    return (completed / _totalRouteDistanceMeters).clamp(0.0, 1.0);
  }

  @override
  void initState() {
    super.initState();
    _currentBus = widget.bus;
    _moveAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _busMotionAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _busMotionAnim.addListener(_onBusAnimFrame);
    _initLocation();
    _listenBus();
    _loadRoute();
    _startBookingMonitor();
    _etaRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) { if (_needEta()) _fetchETA(); });
    _busToMeEtaTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (_needBusToMeEta()) _fetchBusToMeEta();
    });
  }

  void _startBookingMonitor() {
    _bookingStatusSub = _bookingService.getMyBooking(widget.bus.busId).listen((booking) {
      if (!mounted) return;
      setState(() => _myBooking = booking);
      if (booking != null && booking.isWaiting) {
        _bookingMonitor.startMonitoring(booking);
      }
    });
  }

  @override
  void dispose() {
    _busLocationSub?.cancel();
    _myPositionSub?.cancel();
    _etaRefreshTimer?.cancel();
    _busToMeEtaTimer?.cancel();
    _bookingStatusSub?.cancel();
    _bookingMonitor.stopMonitoring();
    // Start foreground monitoring if user has an active booking
    if (_myBooking != null && _myBooking!.isActive) {
      BookingForegroundManager.start(_myBooking!.busId, _myBooking!.lineName);
    }
    _moveAnim.dispose();
    _busMotionAnim.dispose();
    super.dispose();
  }

  // ── Location ──
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
    if (mounted) setState(() => _meToBusText = m < 1000 ? '${m.toStringAsFixed(0)} m' : '${(m / 1000).toStringAsFixed(1)} km');
  }

  // ── Bus stream ──
  void _listenBus() {
    _busLocationSub = _locationService.getBusLocationStream(widget.bus.busId).listen((loc) {
      if (!mounted) return;
      if (loc == null) { setState(() { _busOffline = true; }); return; }
      final wasOffline = _busOffline;
      _startBusAnimation(loc.latLng);
      setState(() { _busLocation = loc; _busOffline = false; _lastUpdateTime = DateFormat('HH:mm').format(DateTime.now()); });
      if (wasOffline && !_notifiedTripStart) {
        _notifiedTripStart = true;
        NotificationService.showNotification(title: '🚌 Trajet démarré', body: '${widget.bus.lineName} est en route !', id: 10);
      }
      _calcMeToBus();
      _updateDepartToBus();
      _splitRoute();
      if (_needEta()) _fetchETA();
      if (_needBusToMeEta()) _fetchBusToMeEta();
      if (_followBus) _mapController.move(loc.latLng, _mapController.camera.zoom);
    }, onError: (_) {
      if (mounted) setState(() { _busOffline = true; });
    });
    _busService.getBusById(widget.bus.busId).listen((b) { if (mounted && b != null) setState(() => _currentBus = b); });
  }

  // ── Route & ETA ──
  Future<void> _loadRoute() async {
    final b = _currentBus ?? widget.bus;
    if (!b.hasDeparture || !b.hasArrival) return;
    final r = await RouteService.getRoute(LatLng(b.departureLat!, b.departureLng!), LatLng(b.arrivalLat!, b.arrivalLng!));
    if (mounted && r != null && r.points.isNotEmpty) {
      setState(() {
        _fullRoute = r.points;
        _leftRoute = List.from(r.points);
        _doneRoute = [];
        _routeOk = true;
        _totalRouteDistanceMeters = r.distanceMeters;
      });
      _splitRoute();
      _animatedFit(_fullRoute);
      _detectStops();
    }
  }

  Future<void> _fetchETA() async {
    final b = _currentBus ?? widget.bus;
    if (_busLocation == null || !b.hasArrival) return;
    final r = await RouteService.getRoute(_busLocation!.latLng, LatLng(b.arrivalLat!, b.arrivalLng!));
    if (mounted && r != null) {
      final arr = DateTime.now().add(Duration(seconds: r.durationSeconds.round()));
      setState(() {
        _etaMinutes = r.etaMinutes;
        _etaDurationSeconds = r.durationSeconds;
        _etaText = r.etaText;
        _distText = r.distanceText;
        _distanceBusToArrivalMeters = r.distanceMeters;
        _arrText = DateFormat('HH:mm').format(arr);
        _lastEtaPos = _busLocation!.latLng;
      });
      _checkNotifs();
      _computeStopETAs();
    }
  }

  void _updateDepartToBus() {
    final b = _currentBus ?? widget.bus;
    if (_busLocation != null && b.hasDeparture) {
      final m = const Distance().as(
        LengthUnit.Meter,
        LatLng(b.departureLat!, b.departureLng!),
        _busLocation!.latLng,
      );
      if (mounted) {
        setState(() {
          _distanceDepartToBusText = m < 1000
              ? '${m.toStringAsFixed(0)} m'
              : '${(m / 1000).toStringAsFixed(1)} km';
        });
      }
    }
  }

  void _checkNotifs() {
    if (_etaMinutes <= 10 && _etaMinutes > 5 && !_notified10min) {
      _notified10min = true;
      NotificationService.showNotification(title: '🚌 Bus arrive dans ~10 min', body: '${widget.bus.lineName} — Préparez-vous.', id: 11);
    }
    if (_etaMinutes <= 5 && !_notified5min) {
      _notified5min = true;
      NotificationService.showNotification(title: '🚌 Bus arrive dans ~5 min !', body: '${widget.bus.lineName} est presque là !', id: 12);
    }
  }

  void _splitRoute() {
    if (!_routeOk || _fullRoute.isEmpty || _busLocation == null) return;
    double min = double.infinity; int idx = 0; const d = Distance();
    for (int i = 0; i < _fullRoute.length; i++) { final v = d.as(LengthUnit.Meter, _busLocation!.latLng, _fullRoute[i]); if (v < min) { min = v; idx = i; } }
    _busRouteIdx = idx;

    if (idx == 0 && min > 100) {
      setState(() { _doneRoute = []; _leftRoute = List.from(_fullRoute); });
      if (!_preRouteLoaded) _fetchPreRoute();
    } else {
      if (_preRoute.isNotEmpty) setState(() { _preRoute = []; _preRouteLoaded = false; });
      setState(() { _doneRoute = [..._fullRoute.sublist(0, idx + 1), _busLocation!.latLng]; _leftRoute = [_busLocation!.latLng, ..._fullRoute.sublist(idx)]; });
    }
  }

  // ── Stop detection & ETA ──
  Future<void> _detectStops() async {
    final b = _currentBus ?? widget.bus;
    if (!b.hasDeparture || !b.hasArrival || _fullRoute.isEmpty) return;

    final stopNames = await BusService.fetchLineStops(b.lineId);
    if (!mounted) return;

    final stops = StopDetection.resolveAdminStops(
      stopNames: stopNames,
      routePoints: _fullRoute,
      departureLat: b.departureLat!,
      departureLng: b.departureLng!,
      arrivalLat: b.arrivalLat!,
      arrivalLng: b.arrivalLng!,
    );

    if (mounted) {
      setState(() {
        _routeStops = stops;
        _stopETAs = List.filled(stops.length, -1);
      });
    }
  }

  void _computeStopETAs() {
    if (_routeStops.isEmpty || _fullRoute.isEmpty || _busRouteIdx < 0) return;
    const d = Distance();

    double totalRemDist = 0;
    for (int i = _busRouteIdx; i < _fullRoute.length - 1; i++) {
      totalRemDist += d.as(LengthUnit.Meter, _fullRoute[i], _fullRoute[i + 1]);
    }
    if (totalRemDist <= 0) return;

    final newETAs = List.filled(_routeStops.length, -1);
    for (int j = 0; j < _routeStops.length; j++) {
      final stop = _routeStops[j];
      if (stop.routeIndex <= _busRouteIdx) {
        newETAs[j] = 0;
        continue;
      }
      double distToStop = 0;
      final endIdx = (stop.routeIndex - 1).clamp(0, _fullRoute.length - 1);
      for (int i = _busRouteIdx; i < endIdx; i++) {
        distToStop += d.as(LengthUnit.Meter, _fullRoute[i], _fullRoute[i + 1]);
      }
      final fraction = distToStop / totalRemDist;
      newETAs[j] = (fraction * _etaDurationSeconds / 60).round();
    }
    if (mounted) setState(() => _stopETAs = newETAs);
  }

  bool get _hasUpcomingStops {
    if (!_routeOk || _busRouteIdx < 0 || _busLocation == null) return false;
    return _routeStops.any((s) => s.routeIndex > _busRouteIdx);
  }

  List<MapEntry<RouteStop, int>> get _upcomingStopsWithETA {
    final out = <MapEntry<RouteStop, int>>[];
    for (int i = 0; i < _routeStops.length; i++) {
      if (_routeStops[i].routeIndex > _busRouteIdx) {
        out.add(MapEntry(_routeStops[i], i < _stopETAs.length ? _stopETAs[i] : -1));
      }
    }
    return out;
  }

  Future<void> _fetchPreRoute() async {
    final b = _currentBus ?? widget.bus;
    if (_busLocation == null || !b.hasDeparture) return;
    _preRouteLoaded = true;
    final r = await RouteService.getRoute(_busLocation!.latLng, LatLng(b.departureLat!, b.departureLng!));
    if (mounted && r != null && r.points.isNotEmpty) {
      setState(() => _preRoute = r.points);
    }
  }

  bool _needEta() => _lastEtaPos == null || _busLocation == null || const Distance().as(LengthUnit.Meter, _lastEtaPos!, _busLocation!.latLng) >= 100;

  Future<void> _fetchBusToMeEta() async {
    if (_myPosition == null || _busLocation == null) return;
    final r = await RouteService.getRoute(_busLocation!.latLng, _myPosition!);
    if (mounted && r != null) {
      setState(() {
        _busToMeEtaText = r.etaMinutes < 1 ? 'Imminent' : '~${r.etaMinutes} min';
        _lastBusToMeEtaPos = _busLocation!.latLng;
      });
    }
  }

  bool _needBusToMeEta() {
    if (_myPosition == null || _busLocation == null) return false;
    if (_lastBusToMeEtaPos == null) return true;
    return const Distance().as(LengthUnit.Meter, _lastBusToMeEtaPos!, _busLocation!.latLng) >= 200;
  }

  // ── Smooth bus animation ──
  void _onBusAnimFrame() {
    if (_prevSmooth == null || _busLocation == null) return;
    final t = Curves.easeInOutCubic.transform(_busMotionAnim.value);
    final target = _busLocation!.latLng;
    if (mounted) {
      setState(() {
        _smoothBusPos = LatLng(
          _prevSmooth!.latitude + (target.latitude - _prevSmooth!.latitude) * t,
          _prevSmooth!.longitude + (target.longitude - _prevSmooth!.longitude) * t,
        );
      });
    }
  }

  void _startBusAnimation(LatLng newTarget) {
    _prevSmooth = _smoothBusPos ?? newTarget;
    _busMotionAnim.reset();
    _busMotionAnim.forward();
  }

  // ── Tap on route ──
  void _onRouteTap(LatLng ll) {
    if (_leftRoute.length < 2 || _busLocation == null) return;
    double min = double.infinity; int idx = 0; const d = Distance();
    for (int i = 0; i < _leftRoute.length; i++) { final v = d.as(LengthUnit.Meter, ll, _leftRoute[i]); if (v < min) { min = v; idx = i; } }
    if (min > 100) return;
    setState(() { _tapPt = _leftRoute[idx]; _tapEta = null; _tapDist = null; _tapLoading = true; });
    _fetchTapEta(_leftRoute[idx]);
  }

  Future<void> _fetchTapEta(LatLng pt) async {
    if (_busLocation == null) return;
    final r = await RouteService.getRoute(_busLocation!.latLng, pt);
    if (mounted) {
      if (r != null) {
        setState(() { _tapEta = r.etaText; _tapDist = r.distanceText; _tapLoading = false; });
      } else {
        setState(() { _tapEta = '--'; _tapLoading = false; });
      }
    }
  }

  // ── Animated camera ──
  void _animatedMoveTo(LatLng target, double targetZoom) {
    _moveAnim.stop();
    if (_moveAnimListener != null) {
      _moveAnim.removeListener(_moveAnimListener!);
      _moveAnimListener = null;
    }
    final startCenter = _mapController.camera.center;
    final startZoom   = _mapController.camera.zoom;
    final curved = CurvedAnimation(parent: _moveAnim, curve: Curves.easeInOutCubic);

    _moveAnimListener = () {
      final t   = curved.value;
      final lat = startCenter.latitude  + (target.latitude  - startCenter.latitude)  * t;
      final lng = startCenter.longitude + (target.longitude - startCenter.longitude) * t;
      _mapController.move(LatLng(lat, lng), startZoom + (targetZoom - startZoom) * t);
    };

    _moveAnim
      ..addListener(_moveAnimListener!)
      ..reset()
      ..forward().whenCompleteOrCancel(() {
        if (_moveAnimListener != null) {
          _moveAnim.removeListener(_moveAnimListener!);
          _moveAnimListener = null;
        }
        curved.dispose();
      });
  }

  void _animatedFit(List<LatLng> points) {
    if (points.length < 2) return;
    final targetCamera = CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(points),
      padding: const EdgeInsets.all(80),
      maxZoom: 16,
    ).fit(_mapController.camera);
    _animatedMoveTo(targetCamera.center, targetCamera.zoom);
  }

  // ── Controls ──
  void _fitAll() {
    final b = _currentBus ?? widget.bus; final pts = <LatLng>[];
    if (_myPosition != null) pts.add(_myPosition!);
    if (_busLocation != null) pts.add(_busLocation!.latLng);
    if (b.hasDeparture) pts.add(LatLng(b.departureLat!, b.departureLng!));
    if (b.hasArrival) pts.add(LatLng(b.arrivalLat!, b.arrivalLng!));
    if (pts.length >= 2) { _mapController.fitCamera(CameraFit.bounds(bounds: LatLngBounds.fromPoints(pts), padding: const EdgeInsets.all(80))); setState(() => _followBus = false); }
  }

  // ══════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final bus = _currentBus ?? widget.bus;
    final live = _busLocation != null && !_busOffline;
    final primary = context.appPrimary;
    final isDark = context.isDark;

    Color etaColor;
    if (_etaMinutes <= 5) {
      etaColor = context.appGreen;
    } else if (_etaMinutes <= 15) {
      etaColor = context.appOrange;
    } else {
      etaColor = context.appRed;
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: context.appBg,
        appBar: AppBar(
          backgroundColor: context.appCardBg,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, size: 22, color: context.appText),
            onPressed: () => Navigator.pop(context),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(bus.lineName,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.appText),
                  overflow: TextOverflow.ellipsis),
              if (bus.busName.isNotEmpty)
                Text(bus.busName,
                    style: TextStyle(fontSize: 11, color: context.appSub),
                    overflow: TextOverflow.ellipsis),
            ],
          ),
          actions: [
            if (live)
              Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: context.appGreen,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.circle, size: 6, color: Colors.white),
                  const SizedBox(width: 4),
                  const Text('LIVE',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ]),
              ),
          ],
        ),
        body: Column(
          children: [
            // ── Map — top 40% ──────────────────────────────────────────────
            Flexible(
              flex: 40,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _myPosition ?? (live ? _busLocation!.latLng : _center),
                      initialZoom: live ? 14 : 12,
                      onTap: (_, ll) {
                        if (_tapPt != null) {
                          if (_leftRoute.length >= 2 && _busLocation != null) {
                            double min = double.infinity; const d = Distance();
                            for (final p in _leftRoute) { final v = d.as(LengthUnit.Meter, ll, p); if (v < min) min = v; }
                            if (min < 60) { _onRouteTap(ll); return; }
                          }
                          setState(() { _tapPt = null; _tapEta = null; _tapDist = null; });
                        } else {
                          _onRouteTap(ll);
                        }
                      },
                      onPositionChanged: (_, g) { if (g && _followBus) setState(() => _followBus = false); },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: RouteService.tileUrl,
                        userAgentPackageName: 'com.example.voyageur_app',
                        tileSize: config.mapTileSize,
                        zoomOffset: config.mapZoomOffset,
                      ),

                      if (_preRoute.length >= 2)
                        PolylineLayer(polylines: [Polyline(points: _preRoute, color: primary.withValues(alpha: 0.5), strokeWidth: 8)]),

                      if (_doneRoute.length >= 2)
                        PolylineLayer(polylines: [Polyline(points: _doneRoute, color: const Color(0xFFBDC1C6), strokeWidth: 12)]),

                      if (_leftRoute.length >= 2)
                        PolylineLayer(polylines: [Polyline(points: _leftRoute, color: primary, strokeWidth: 12)]),

                      if (!_routeOk && live && bus.hasArrival)
                        PolylineLayer(polylines: [Polyline(points: [_busLocation!.latLng, LatLng(bus.arrivalLat!, bus.arrivalLng!)], color: primary.withValues(alpha: 0.5), strokeWidth: 4)]),

                      MarkerLayer(markers: [
                        if (bus.hasDeparture)
                          Marker(point: LatLng(bus.departureLat!, bus.departureLng!), width: 18, height: 18,
                              child: Container(decoration: BoxDecoration(color: context.appGreen, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),

                        if (bus.hasArrival)
                          Marker(point: LatLng(bus.arrivalLat!, bus.arrivalLng!), width: 36, height: 42,
                              child: Icon(Icons.location_on, color: context.appRed, size: 42)),

                        for (int i = 0; i < _routeStops.length; i++)
                          Marker(
                            point: _routeStops[i].latLng,
                            width: 46,
                            height: 36,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _routeStops[i].routeIndex > _busRouteIdx
                                        ? context.appOrange.withValues(alpha: 0.92)
                                        : const Color(0xFFBDC1C6),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _routeStops[i].name.split(' ').first,
                                    style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w700, color: Colors.white),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Container(
                                  width: 8, height: 8,
                                  decoration: BoxDecoration(
                                    color: _routeStops[i].routeIndex > _busRouteIdx
                                        ? context.appOrange
                                        : const Color(0xFFBDC1C6),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 1.5),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        if (_myPosition != null)
                          Marker(point: _myPosition!, width: 22, height: 22,
                              child: Container(decoration: BoxDecoration(color: primary, shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2.5),
                                  boxShadow: [BoxShadow(color: primary.withValues(alpha: 0.3), blurRadius: 8)]))),

                        if (live)
                          Marker(
                            point: _smoothBusPos ?? _busLocation!.latLng,
                            width: 80,
                            height: 100,
                            alignment: const Alignment(0, 0.09),
                            child: _BusMarker(
                              busName: bus.busName.isNotEmpty ? bus.busName : bus.lineName,
                              speedText: _busLocation!.speedText,
                              primaryColor: primary,
                            ),
                          ),

                        if (_tapPt != null)
                          Marker(point: _tapPt!, width: 130, height: 56, child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(color: context.appCardBg, borderRadius: BorderRadius.circular(20),
                                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 2))]),
                                child: _tapLoading
                                    ? SizedBox(width: 14, height: 14, child: BusLoadingIndicator(strokeWidth: 2, color: primary))
                                    : Row(mainAxisSize: MainAxisSize.min, children: [
                                  Text(_tapEta ?? '--', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.appText)),
                                  if (_tapDist != null) ...[
                                    Text('  ·  ', style: TextStyle(color: context.appSub, fontSize: 10)),
                                    Text(_tapDist!, style: TextStyle(fontSize: 10, color: context.appSub)),
                                  ],
                                ])),
                            Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 2),
                                decoration: BoxDecoration(color: primary, shape: BoxShape.circle)),
                          ])),
                      ]),
                    ],
                  ),

                  // Offline / not on trip banner
                  if (_busOffline || (!live && _busLocation == null))
                    Positioned(
                      top: 0, left: 0, right: 0,
                      child: Material(
                        color: context.appCardBg,
                        elevation: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(children: [
                            Icon(live ? Icons.gps_off : Icons.directions_bus, color: context.appOrange, size: 18),
                            const SizedBox(width: 10),
                            Expanded(child: Text(
                              _currentBus?.isOnTrip == true
                                  ? 'Localisation du chauffeur en cours...'
                                  : 'Le chauffeur n\'est pas en trajet actuellement',
                              style: TextStyle(fontSize: 13, color: context.appText),
                            )),
                          ]),
                        ),
                      ),
                    ),

                  // Map controls (top-right)
                  Positioned(
                    top: 10,
                    right: 12,
                    child: Column(children: [
                      _Btn(Icons.crop_free, _fitAll),
                      const SizedBox(height: 8),
                      if (live) ...[
                        _Btn(Icons.directions_bus, () { setState(() => _followBus = true); _animatedMoveTo(_busLocation!.latLng, 16); }, tint: _followBus ? primary : null),
                        const SizedBox(height: 8),
                      ],
                      if (_myPosition != null)
                        _Btn(Icons.my_location, () { _followBus = false; _animatedMoveTo(_myPosition!, 16); }, tint: primary),
                    ]),
                  ),
                ],
              ),
            ),

            // ── Scrollable details — bottom 60% ───────────────────────────
            Flexible(
              flex: 60,
              child: Container(
                decoration: BoxDecoration(
                  color: context.appCardBg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ─ Bus header ─
                      Row(children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.directions_bus, color: primary, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(
                            bus.busName.isNotEmpty ? bus.busName : bus.lineName,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: context.appText),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            bus.busNumber.isNotEmpty ? 'N° ${bus.busNumber}' : bus.statusText,
                            style: TextStyle(fontSize: 12, color: context.appSub),
                          ),
                        ])),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: bus.isOnTrip ? context.appGreen.withValues(alpha: 0.1) : context.appCardBg2,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            bus.statusText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: bus.isOnTrip ? context.appGreen : context.appSub,
                            ),
                          ),
                        ),
                      ]),

                      // ─ Booking button ─
                      if (live && bus.hasArrival) ...[
                        const SizedBox(height: 12),
                        BookingButton(bus: bus, etaMinutes: _etaMinutes),
                      ],

                      // ─ Boarding status indicator ─
                      if (_myBooking != null && _myBooking!.isActive) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _myBooking!.isBoarded
                                ? context.appGreen.withValues(alpha: 0.08)
                                : context.appOrange.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _myBooking!.isBoarded
                                  ? context.appGreen.withValues(alpha: 0.3)
                                  : context.appOrange.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(children: [
                            Icon(
                              _myBooking!.isBoarded ? Icons.check_circle : Icons.hourglass_top,
                              size: 16,
                              color: _myBooking!.isBoarded ? context.appGreen : context.appOrange,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _myBooking!.isBoarded ? 'À bord du bus' : 'En attente du bus...',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _myBooking!.isBoarded ? context.appGreen : context.appOrange,
                              ),
                            ),
                          ]),
                        ),
                      ],

                      Divider(height: 24, color: context.appBorder),

                      if (live) ...[
                        // ─ Progress bar ─
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text(
                            'Progression du trajet',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.appSub),
                          ),
                          Text(
                            '${(_routeProgress * 100).toStringAsFixed(0)}%',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: context.appGreen),
                          ),
                        ]),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _routeProgress,
                            minHeight: 7,
                            backgroundColor: context.appBorder,
                            valueColor: AlwaysStoppedAnimation<Color>(context.appGreen),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Row(children: [
                            Container(width: 8, height: 8,
                                decoration: BoxDecoration(color: context.appGreen, borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: 4),
                            Text(
                              _distanceDepartToBusText == '--' ? 'Départ' : _distanceDepartToBusText,
                              style: TextStyle(fontSize: 10, color: context.appGreen, fontWeight: FontWeight.w600),
                            ),
                            if (_distanceDepartToBusText != '--')
                              Text(' parcourus', style: TextStyle(fontSize: 10, color: context.appSub)),
                          ]),
                          Row(children: [
                            Text(
                              _distText == '--' ? 'Arrivée' : _distText,
                              style: TextStyle(fontSize: 10, color: context.appRed, fontWeight: FontWeight.w600),
                            ),
                            if (_distText != '--')
                              Text(' restants', style: TextStyle(fontSize: 10, color: context.appSub)),
                            const SizedBox(width: 4),
                            Container(width: 8, height: 8,
                                decoration: BoxDecoration(color: context.appRed, borderRadius: BorderRadius.circular(2))),
                          ]),
                        ]),

                        const SizedBox(height: 18),

                        // ─ ETA card ─
                        if (bus.hasArrival)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: etaColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: etaColor.withValues(alpha: 0.25)),
                            ),
                            child: Row(children: [
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('Temps estimé', style: TextStyle(fontSize: 11, color: context.appSub)),
                                const SizedBox(height: 4),
                                Text(_etaText, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: etaColor)),
                              ])),
                              Container(width: 1, height: 50, color: context.appBorder),
                              const SizedBox(width: 16),
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('Arrivée estimée', style: TextStyle(fontSize: 11, color: context.appSub)),
                                const SizedBox(height: 4),
                                Row(children: [
                                  Icon(Icons.schedule, size: 16, color: primary),
                                  const SizedBox(width: 4),
                                  Text(_arrText, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: context.appText)),
                                ]),
                              ]),
                            ]),
                          ),

                        // ─ Bus → Moi ─
                        if (_myPosition != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: primary.withValues(alpha: 0.18)),
                            ),
                            child: Row(children: [
                              Icon(Icons.person_pin_circle, color: primary, size: 20),
                              const SizedBox(width: 10),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('Bus → Ma position', style: TextStyle(fontSize: 11, color: context.appSub)),
                                const SizedBox(height: 2),
                                Text(_busToMeEtaText, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: primary)),
                              ])),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: context.appBorder.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(_meToBusText, style: TextStyle(fontSize: 11, color: context.appSub, fontWeight: FontWeight.w500)),
                              ),
                            ]),
                          ),
                        ],

                        const SizedBox(height: 14),

                        // ─ Speed + last update ─
                        Row(children: [
                          _Stat(Icons.speed, _busLocation!.speedText, 'Vitesse'),
                          Container(width: 1, height: 28, color: context.appBorder),
                          _Stat(Icons.update, _lastUpdateTime, 'Mise à jour'),
                        ]),

                        // ─ Upcoming stops ─
                        if (_hasUpcomingStops) ...[
                          const SizedBox(height: 14),
                          Divider(height: 1, color: context.appBorder),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(children: [
                              Icon(Icons.place_outlined, size: 13, color: context.appSub),
                              const SizedBox(width: 5),
                              Text('Prochains arrêts',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.appSub, letterSpacing: 0.3)),
                            ]),
                          ),
                          SizedBox(
                            height: 60,
                            child: ListView.separated(
                              padding: EdgeInsets.zero,
                              scrollDirection: Axis.horizontal,
                              itemCount: _upcomingStopsWithETA.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 8),
                              itemBuilder: (_, i) {
                                final entry = _upcomingStopsWithETA[i];
                                final etaMin = entry.value;
                                final etaLabel = etaMin < 0
                                    ? '--'
                                    : etaMin == 0
                                        ? 'Imminent'
                                        : '~$etaMin min';
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: context.appOrange.withValues(alpha: 0.07),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: context.appOrange.withValues(alpha: 0.25)),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(mainAxisSize: MainAxisSize.min, children: [
                                        Container(width: 6, height: 6,
                                            decoration: BoxDecoration(color: context.appOrange, shape: BoxShape.circle)),
                                        const SizedBox(width: 5),
                                        Text(entry.key.name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.appText)),
                                      ]),
                                      const SizedBox(height: 3),
                                      Text(etaLabel, style: TextStyle(fontSize: 10, color: context.appSub)),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],

                        const SizedBox(height: 14),

                        // ─ Route legend ─
                        Row(children: [
                          Expanded(child: _LegendItem(color: const Color(0xFFBDC1C6), label: 'Parcouru')),
                          const SizedBox(width: 8),
                          Expanded(child: _LegendItem(color: primary, label: 'Restant')),
                          const SizedBox(width: 8),
                          Expanded(child: _LegendItem(color: primary.withValues(alpha: 0.5), label: 'Avant départ')),
                        ]),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: context.appOrange.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(children: [
                            Icon(Icons.wifi_off, color: context.appOrange, size: 18),
                            const SizedBox(width: 10),
                            Expanded(child: Text(
                              'Aucune donnée disponible pour ce bus.',
                              style: TextStyle(color: context.appText, fontSize: 13),
                            )),
                          ]),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widgets ──
class _Btn extends StatefulWidget {
  final IconData icon; final VoidCallback onTap; final Color? tint;
  const _Btn(this.icon, this.onTap, {this.tint});
  @override
  State<_Btn> createState() => _BtnState();
}

class _BtnState extends State<_Btn> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onTap() {
    _animController.forward().then((_) => _animController.reverse());
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return Material(color: context.appCardBg, shape: const CircleBorder(), elevation: 2, shadowColor: Colors.black26,
        child: InkWell(customBorder: const CircleBorder(), onTap: _onTap,
            child: Padding(padding: const EdgeInsets.all(11),
                child: AnimatedBuilder(
                  animation: _scaleAnimation,
                  builder: (context, child) {
                    return Transform.scale(scale: _scaleAnimation.value, child: child);
                  },
                  child: Icon(widget.icon, size: 22, color: widget.tint ?? context.appSub),
                ))));
  }
}

class _Stat extends StatelessWidget {
  final IconData icon; final String value; final String label;
  const _Stat(this.icon, this.value, this.label);
  @override
  Widget build(BuildContext context) {
    return Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 16, color: context.appSub),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.appText)),
        Text(label, style: TextStyle(fontSize: 10, color: context.appSub)),
      ]),
    ]));
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 20, height: 4,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
      ),
      const SizedBox(width: 6),
      Flexible(
        child: Text(label,
            style: TextStyle(fontSize: 10, color: context.appSub),
            overflow: TextOverflow.ellipsis),
      ),
    ]);
  }
}

class _BusMarker extends StatefulWidget {
  final String busName;
  final String speedText;
  final Color primaryColor;
  const _BusMarker({required this.busName, required this.speedText, required this.primaryColor});
  @override
  State<_BusMarker> createState() => _BusMarkerState();
}

class _BusMarkerState extends State<_BusMarker> with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: widget.primaryColor,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(color: widget.primaryColor.withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
          child: Text(widget.busName,
            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis, maxLines: 1),
        ),
        CustomPaint(size: const Size(10, 5), painter: _TrianglePainter(color: widget.primaryColor)),
        AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (_, child) {
            final t = _pulseCtrl.value;
            return Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 36 + 20 * t,
                  height: 36 + 20 * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.primaryColor.withValues(alpha: 0.28 * (1.0 - t)),
                  ),
                ),
                Container(
                  width: 36 + 10 * t,
                  height: 36 + 10 * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.primaryColor.withValues(alpha: 0.18 * (1.0 - t)),
                  ),
                ),
                child!,
              ],
            );
          },
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: widget.primaryColor.withValues(alpha: 0.35), blurRadius: 10, spreadRadius: 1),
                BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 6),
              ],
            ),
            child: Center(child: Container(
              width: 28, height: 28,
              decoration: BoxDecoration(color: widget.primaryColor, shape: BoxShape.circle),
              child: const Icon(Icons.directions_bus, color: Colors.white, size: 18),
            )),
          ),
        ),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4)],
          ),
          child: Text(widget.speedText,
            style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
        ),
      ],
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  const _TrianglePainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final path = ui.Path()
      ..moveTo(0, 0)..lineTo(size.width, 0)..lineTo(size.width / 2, size.height)..close();
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.fill);
  }
  @override
  bool shouldRepaint(_TrianglePainter o) => o.color != color;
}
