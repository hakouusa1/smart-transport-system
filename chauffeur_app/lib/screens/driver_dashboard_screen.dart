import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/bus_model.dart';
import '../services/auth_service.dart';
import '../services/bus_service.dart';
import '../services/location_service.dart';

const _mapboxToken =
    'pk.eyJ1IjoiaGFrb3UwODgiLCJhIjoiY21tZXgxMTJvMDF5eDJyc2hxY2Y3OW1rOCJ9.v74bMi9y79UmP4ixwsuLJw';
const _tileUrl =
    'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/{z}/{x}/{y}@2x?access_token=$_mapboxToken';

// Colors
const _dark = Color(0xFF0F172A);
const _text = Color(0xFF334155);
const _sub = Color(0xFF64748B);
const _border = Color(0xFFE2E8F0);
const _bg = Color(0xFFF8FAFC);
const _blue = Color(0xFF3B82F6);
const _green = Color(0xFF22C55E);
const _red = Color(0xFFEF4444);
const _orange = Color(0xFFF59E0B);

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});
  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> with TickerProviderStateMixin {
  final _authService = AuthService();
  final _busService = BusService();
  final _locationService = LocationService();
  final _mapController = MapController();

  bool _isTripActive = false;
  bool _isProcessing = false;

  // Map / Driving mode
  LatLng _currentPos = const LatLng(36.7538, 3.0588);
  double _speed = 0;
  double _heading = 0;
  StreamSubscription<Position>? _posSub;
  Timer? _etaTimer;

  // Route
  List<LatLng> _fullRoute = [];
  List<LatLng> _doneRoute = [];
  List<LatLng> _leftRoute = [];
  double? _departureLat, _departureLng, _arrivalLat, _arrivalLng;

  // ETA
  double? _etaMin;
  double? _distKm;
  String _arrivalTime = '--:--';
  LatLng? _lastEtaPos;

  // Animation
  late AnimationController _transitionAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _transitionAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _transitionAnim, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _locationService.dispose();
    _posSub?.cancel();
    _etaTimer?.cancel();
    _transitionAnim.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  // ═══════════════════════════════════════
  // TRIP CONTROLS
  // ═══════════════════════════════════════
  Future<void> _startTrip(Bus bus) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      await _locationService.checkAndRequestPermissions();
      await _busService.startTrip(bus.busId);
      _locationService.startTracking(bus.busId); // don't await — let it start in background

      // Set route endpoints
      _departureLat = bus.departureLat;
      _departureLng = bus.departureLng;
      _arrivalLat = bus.arrivalLat;
      _arrivalLng = bus.arrivalLng;

      // Show driving mode IMMEDIATELY — don't wait for route
      setState(() => _isTripActive = true);
      _transitionAnim.forward();

      // Start GPS stream for map
      _startGPSStream(bus.busId);

      // Load route in background (non-blocking)
      _loadRoute();

      // Start ETA refresh
      _etaTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchETA());

      // Enable wakelock
      WakelockPlus.enable();
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Trajet démarré !'),
          backgroundColor: _green, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16), duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()), backgroundColor: _red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _stopTrip(Bus bus) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      await _locationService.stopTracking(bus.busId);
      await _busService.endTrip(bus.busId);

      _posSub?.cancel();
      _etaTimer?.cancel();
      WakelockPlus.disable();
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

      _transitionAnim.reverse();
      await Future.delayed(const Duration(milliseconds: 300));

      setState(() { _isTripActive = false; _fullRoute = []; _doneRoute = []; _leftRoute = []; });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Trajet terminé.'),
          backgroundColor: _orange, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16), duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()), backgroundColor: _red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _toggleOnline(Bus bus) async {
    if (_isTripActive) return;
    try {
      if (bus.driverStatus == 'offline') await _busService.goOnline(bus.busId);
      else await _busService.goOffline(bus.busId);
    } catch (_) {}
  }

  // ═══════════════════════════════════════
  // GPS + ROUTE
  // ═══════════════════════════════════════
  void _startGPSStream(String busId) {
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen((pos) {
      if (!mounted) return;

      // FILTER: Ignore inaccurate GPS readings
      if (pos.accuracy > 25) return;

      // FIX SPEED: GPS reports fake speed when stationary
      // Below 1 m/s (3.6 km/h) = noise, set to 0
      double speed = pos.speed;
      if (speed < 1.0) speed = 0.0;

      setState(() {
        _currentPos = LatLng(pos.latitude, pos.longitude);
        _speed = speed * 3.6; // m/s → km/h
        _heading = pos.heading;
      });
      _splitRoute();
      if (_shouldRefreshEta()) _fetchETA();
      _mapController.move(_currentPos, _mapController.camera.zoom);
    });
  }

  Future<void> _loadRoute() async {
    if (_departureLat == null || _arrivalLat == null) return;
    try {
      final url = Uri.parse(
        'https://api.mapbox.com/directions/v5/mapbox/driving/'
            '$_departureLng,$_departureLat;$_arrivalLng,$_arrivalLat'
            '?overview=false&steps=true&geometries=geojson&access_token=$_mapboxToken',
      );
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final legs = data['routes'][0]['legs'] as List;
        final points = <LatLng>[];
        for (final leg in legs) {
          for (final step in leg['steps']) {
            final coords = step['geometry']['coordinates'] as List;
            for (final c in coords) points.add(LatLng(c[1].toDouble(), c[0].toDouble()));
          }
        }
        if (mounted && points.isNotEmpty) {
          setState(() { _fullRoute = points; _leftRoute = List.from(points); _doneRoute = []; });
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchETA() async {
    if (_arrivalLat == null) return;
    try {
      final url = Uri.parse(
        'https://api.mapbox.com/directions/v5/mapbox/driving/'
            '${_currentPos.longitude},${_currentPos.latitude};$_arrivalLng,$_arrivalLat'
            '?access_token=$_mapboxToken',
      );
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final route = jsonDecode(res.body)['routes'][0];
        final dur = route['duration'] as num;
        final dist = route['distance'] as num;
        final arrival = DateTime.now().add(Duration(seconds: dur.round()));
        if (mounted) {
          setState(() {
            _etaMin = dur / 60;
            _distKm = dist / 1000;
            _arrivalTime = DateFormat('HH:mm').format(arrival);
            _lastEtaPos = _currentPos;
          });
        }
      }
    } catch (_) {}
  }

  void _splitRoute() {
    if (_fullRoute.isEmpty) return;
    double min = double.infinity; int idx = 0; const d = Distance();
    for (int i = 0; i < _fullRoute.length; i++) {
      final v = d.as(LengthUnit.Meter, _currentPos, _fullRoute[i]);
      if (v < min) { min = v; idx = i; }
    }
    setState(() {
      _doneRoute = [..._fullRoute.sublist(0, idx + 1), _currentPos];
      _leftRoute = [_currentPos, ..._fullRoute.sublist(idx)];
    });
  }

  bool _shouldRefreshEta() => _lastEtaPos == null || const Distance().as(LengthUnit.Meter, _lastEtaPos!, _currentPos) >= 100;

  // ═══════════════════════════════════════
  // SOS
  // ═══════════════════════════════════════
  void _showSOS(Bus bus) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4, decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('Signaler un incident', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _dark)),
          const SizedBox(height: 16),
          Row(children: [
            _SOSOption(icon: Icons.car_crash, label: 'Accident', color: _red,
                onTap: () => _sendSOS(ctx, bus, 'accident', 'Accident signalé')),
            const SizedBox(width: 10),
            _SOSOption(icon: Icons.schedule, label: 'Retard', color: _orange,
                onTap: () => _sendSOS(ctx, bus, 'delay', 'Retard signalé')),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _SOSOption(icon: Icons.build, label: 'Panne', color: _sub,
                onTap: () => _sendSOS(ctx, bus, 'mechanical', 'Panne mécanique signalée')),
            const SizedBox(width: 10),
            _SOSOption(icon: Icons.block, label: 'Route bloquée', color: _dark,
                onTap: () => _sendSOS(ctx, bus, 'road_blocked', 'Route bloquée signalée')),
          ]),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  Future<void> _sendSOS(BuildContext ctx, Bus bus, String type, String message) async {
    Navigator.pop(ctx);
    try {
      await FirebaseFirestore.instance.collection('incidents').add({
        'busId': bus.busId,
        'lineName': bus.lineName,
        'type': type,
        'message': message,
        'latitude': _currentPos.latitude,
        'longitude': _currentPos.longitude,
        'timestamp': Timestamp.now(),
        'ownerId': bus.ownerId,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('⚠️ $message'), backgroundColor: _orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16), duration: const Duration(seconds: 3),
        ));
      }
    } catch (_) {}
  }

  void _confirmLogout() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Déconnexion', style: TextStyle(fontWeight: FontWeight.w600)),
      content: const Text('Voulez-vous vraiment vous déconnecter ?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        FilledButton(onPressed: () async { Navigator.pop(ctx); _locationService.dispose(); await _authService.signOut(); },
            style: FilledButton.styleFrom(backgroundColor: _red),
            child: const Text('Déconnecter')),
      ],
    ));
  }

  // ═══════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Bus?>(
      stream: _busService.getAssignedBus(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(backgroundColor: _bg,
              body: Center(child: CircularProgressIndicator(color: _blue, strokeWidth: 2.5)));
        }
        final bus = snapshot.data;
        if (bus == null) return _buildNoBus();

        // DRIVING MODE
        if (_isTripActive) return _buildDrivingMode(bus);

        // NORMAL MODE
        return _buildNormalMode(bus);
      },
    );
  }

  // ═══════════════════════════════════════
  // NORMAL MODE (before trip)
  // ═══════════════════════════════════════
  Widget _buildNormalMode(Bus bus) {
    final email = _authService.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header
            Row(children: [
              Container(width: 48, height: 48,
                  decoration: BoxDecoration(color: _blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.person, color: _blue, size: 24)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Bonjour, Chauffeur', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _dark)),
                Text(email, style: const TextStyle(fontSize: 12, color: _sub), overflow: TextOverflow.ellipsis),
              ])),
              GestureDetector(onTap: _confirmLogout,
                  child: Container(width: 40, height: 40,
                      decoration: BoxDecoration(color: _red.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.logout, color: _red, size: 18))),
            ]),
            const SizedBox(height: 24),

            // Bus info card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.directions_bus_rounded, color: _blue, size: 20),
                  const SizedBox(width: 8),
                  const Text('Mon Bus', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _dark)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: bus.driverStatus == 'offline' ? _sub.withValues(alpha: 0.1) : _green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 5, height: 5, decoration: BoxDecoration(
                          color: bus.driverStatus == 'offline' ? _sub : _green, shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      Text(bus.driverStatus == 'offline' ? 'Hors ligne' : 'En ligne',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                              color: bus.driverStatus == 'offline' ? _sub : _green)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 14),
                _InfoRow('Ligne', bus.lineName),
                const SizedBox(height: 8),
                _InfoRow('Bus', bus.busName.isNotEmpty ? bus.busName : 'N° ${bus.busNumber}'),
              ]),
            ),
            const SizedBox(height: 16),

            // Passenger bookings count
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('bookings')
                  .where('busId', isEqualTo: bus.busId)
                  .where('status', whereIn: ['pending', 'confirmed'])
                  .snapshots(),
              builder: (context, snap) {
                final count = snap.data?.docs.length ?? 0;
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _border)),
                  child: Row(children: [
                    Container(width: 40, height: 40,
                        decoration: BoxDecoration(color: _blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.people, color: _blue, size: 20)),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Passagers réservés', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _dark)),
                      Text('Pour ce trajet', style: TextStyle(fontSize: 11, color: _sub)),
                    ])),
                    Text('$count', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: _blue)),
                  ]),
                );
              },
            ),
            const SizedBox(height: 16),

            // Online toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _border)),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(bus.driverStatus == 'offline' ? 'Passer en ligne' : 'En ligne',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: _dark)),
                subtitle: Text(bus.driverStatus == 'offline' ? 'Pour démarrer un trajet' : 'Visible par les voyageurs',
                    style: const TextStyle(fontSize: 11, color: _sub)),
                value: bus.driverStatus != 'offline',
                onChanged: _isTripActive ? null : (_) => _toggleOnline(bus),
                activeColor: _green,
              ),
            ),
            const SizedBox(height: 28),

            // START TRIP BUTTON
            SizedBox(width: double.infinity, height: 64,
              child: ElevatedButton(
                onPressed: (bus.driverStatus == 'offline' || _isProcessing) ? null : () => _startTrip(bus),
                style: ElevatedButton.styleFrom(
                    backgroundColor: _green, foregroundColor: Colors.white, elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    disabledBackgroundColor: _border),
                child: _isProcessing
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.play_arrow_rounded, size: 32),
                  SizedBox(width: 10),
                  Text('Démarrer le trajet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
            if (bus.driverStatus == 'offline')
              const Padding(padding: EdgeInsets.only(top: 10),
                  child: Text('Passez en ligne d\'abord', textAlign: TextAlign.center,
                      style: TextStyle(color: _orange, fontSize: 12))),
          ]),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // DRIVING MODE (during trip)
  // ═══════════════════════════════════════
  Widget _buildDrivingMode(Bus bus) {
    final etaText = _etaMin != null ? '${_etaMin!.round()} min' : '--';
    final distText = _distKm != null ? '${_distKm!.toStringAsFixed(1)} km' : '--';
    final speedText = '${_speed.round()} km/h';

    return Scaffold(
      body: Stack(children: [
        // ── FULL SCREEN MAP ──
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: (_currentPos.latitude != 36.7538)
                ? _currentPos
                : (_departureLat != null ? LatLng(_departureLat!, _departureLng!) : _currentPos),
            initialZoom: 16,
          ),
          children: [
            TileLayer(urlTemplate: _tileUrl, userAgentPackageName: 'com.example.chauffeur_app', tileSize: 512, zoomOffset: -1),

            // Done route (grey)
            if (_doneRoute.length >= 2)
              PolylineLayer(polylines: [
                Polyline(points: _doneRoute, color: const Color(0xFFBDC1C6), strokeWidth: 8),
              ]),

            // Remaining route (blue)
            if (_leftRoute.length >= 2)
              PolylineLayer(polylines: [
                Polyline(points: _leftRoute, color: _blue, strokeWidth: 8),
              ]),

            // Markers
            MarkerLayer(markers: [
              if (_departureLat != null)
                Marker(point: LatLng(_departureLat!, _departureLng!), width: 16, height: 16,
                    child: Container(decoration: BoxDecoration(color: _green, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),
              if (_arrivalLat != null)
                Marker(point: LatLng(_arrivalLat!, _arrivalLng!), width: 30, height: 36,
                    child: const Icon(Icons.location_on, color: _red, size: 36)),
              // Driver position
              Marker(point: _currentPos, width: 44, height: 44,
                  child: Transform.rotate(angle: _heading * 3.14159 / 180,
                      child: Container(decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6)]),
                          child: const Center(child: Icon(Icons.navigation, color: _blue, size: 26))))),
            ]),
          ],
        ),

        // ── TOP: ETA Bar ──
        Positioned(top: 0, left: 0, right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 8, 16, 12),
              decoration: BoxDecoration(color: _dark.withValues(alpha: 0.9)),
              child: Row(children: [
                // ETA
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(etaText, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white)),
                  Text('$distText  ·  Arrivée $_arrivalTime', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7))),
                ])),
                // Speed
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                  child: Column(children: [
                    Text(speedText, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                    Text('Vitesse', style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.6))),
                  ]),
                ),
              ]),
            )),

        // ── SOS BUTTON (always visible, top right below ETA) ──
        Positioned(top: MediaQuery.of(context).padding.top + 80, right: 16,
            child: GestureDetector(
              onTap: () => _showSOS(bus),
              child: Container(width: 52, height: 52,
                  decoration: BoxDecoration(color: _red, borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: _red.withValues(alpha: 0.4), blurRadius: 10)]),
                  child: const Icon(Icons.warning_rounded, color: Colors.white, size: 28)),
            )),

        // ── BOTTOM: End Trip ──
        Positioned(bottom: 0, left: 0, right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 20),
              decoration: BoxDecoration(color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, -2))]),
              child: SizedBox(height: 60,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : () => _stopTrip(bus),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _red, foregroundColor: Colors.white, elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: _isProcessing
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.stop_rounded, size: 30),
                    SizedBox(width: 10),
                    Text('Terminer le trajet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            )),

        // ── LINE NAME (subtle, top center below ETA) ──
        Positioned(top: MediaQuery.of(context).padding.top + 80, left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)]),
              child: Text(bus.lineName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _dark)),
            )),
      ]),
    );
  }

  // ═══════════════════════════════════════
  // NO BUS
  // ═══════════════════════════════════════
  Widget _buildNoBus() {
    return Scaffold(backgroundColor: _bg, body: Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.directions_bus_outlined, size: 64, color: _border),
        const SizedBox(height: 20),
        const Text('Aucun bus assigné', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _dark)),
        const SizedBox(height: 8),
        const Text('Le propriétaire n\'a pas encore assigné de bus.', textAlign: TextAlign.center, style: TextStyle(color: _sub, height: 1.4)),
      ]),
    )));
  }
}

// ═══════════════════════════════════════
// HELPER WIDGETS
// ═══════════════════════════════════════
class _InfoRow extends StatelessWidget {
  final String label; final String value;
  const _InfoRow(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text('$label:', style: const TextStyle(fontSize: 13, color: _sub)),
      const SizedBox(width: 8),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _dark))),
    ]);
  }
}

class _SOSOption extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  const _SOSOption({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14),
          child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14),
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Column(children: [
                    Icon(icon, color: color, size: 28),
                    const SizedBox(height: 6),
                    Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
                  ])))),
    );
  }
}