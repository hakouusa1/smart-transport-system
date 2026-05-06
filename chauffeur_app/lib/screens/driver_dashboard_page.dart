import 'dart:async';
import 'dart:convert';
import 'dart:math' show cos, sin, pow;
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../app_config.dart' as config;
import '../data/wilayas_data.dart';
import '../models/bus_model.dart';
import '../services/auth_service.dart';
import '../services/bus_service.dart';
import '../services/location_service.dart';
import '../services/notify_service.dart';
import '../theme_notifier.dart';
import 'profile_page.dart';

// Map tile URL logic is moved to app_config.dart
const _green  = Color(0xFF2E7D32);
const _red    = Color(0xFFD32F2F);
const _orange = Color(0xFFF57C00);

class DriverDashboardPage extends StatefulWidget {
  const DriverDashboardPage({super.key});
  @override
  State<DriverDashboardPage> createState() => _DriverDashboardPageState();
}

class _DriverDashboardPageState extends State<DriverDashboardPage> with TickerProviderStateMixin {
  final _auth   = AuthService();
  final _busSvc = BusService();
  final _locSvc = LocationService();
  final _map    = MapController();

  bool _tripActive  = false;
  bool _processing  = false;
  bool? _onlineOptimistic;
  Bus? _bus;
  int  _tripsCompleted = 0; // session counter — increments every time a trip ends


  // GPS
  LatLng _pos     = const LatLng(36.7538, 3.0588);
  LatLng _animPos = const LatLng(36.7538, 3.0588);
  double _speed   = 0, _heading = 0;
  StreamSubscription<Position>?     _gpsSub;
  StreamSubscription<CompassEvent>? _compassSub;
  Timer? _etaTimer;
  bool   _follow = true;
  AnimationController? _markerAnim;

  // GPS pre-warm (background fix before trip starts)
  LatLng? _warmPos;
  StreamSubscription<Position>? _warmUpSub;
  bool _permissionGranted = false;
  bool _gotFirstFix = false;

  // Route
  List<LatLng> _fullRoute = [], _doneRoute = [], _leftRoute = [], _preRoute = [];
  bool _preRouteLoaded = false;
  bool _isRerouting = false;
  double? _depLat, _depLng, _arrLat, _arrLng;

  // ETA
  double? _etaMin, _distKm;
  double _accumulatedDistKm = 0.0;
  LatLng? _lastDistPos;
  String  _arrTime = '--:--';
  LatLng? _lastEtaPos;

  // Trip stats
  DateTime? _tripStartTime;
  double?   _initialDistKm;

  StreamSubscription<Bus?>? _busSub;
  bool _busLoaded = false;

  String get _mapTileUrl {
    if (!config.useMapbox) return config.mapTileUrl;
    return 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/{z}/{x}/{y}@2x?access_token=${config.mapboxToken}';
  }

  @override
  void initState() {
    super.initState();
    _restorePersistedTripStart();
    _busSub = _busSvc.getAssignedBus().listen((bus) {
      if (mounted) {
        setState(() {
          _busLoaded = true;
          if (bus != null) _bus = bus;
        });
        if (bus != null && _warmPos == null && !_tripActive) {
          _preWarmGPS();
        }
      }
    });
  }

  Future<void> _restorePersistedTripStart() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt('trip_start_ms');
    if (ms != null) {
      _tripStartTime = DateTime.fromMillisecondsSinceEpoch(ms);
    }
  }

  Future<void> _preWarmGPS() async {
    if (_tripActive) return;

    _permissionGranted = await _locSvc.checkAndRequestPermissions();
    if (!_permissionGranted || !mounted) return;

    final lastKnown = await Geolocator.getLastKnownPosition();
    if (lastKnown != null && mounted) {
      setState(() => _warmPos = LatLng(lastKnown.latitude, lastKnown.longitude));
    }

    _warmUpSub?.cancel();
    _warmUpSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      ),
    ).listen((pos) {
      if (!mounted) return;
      setState(() => _warmPos = LatLng(pos.latitude, pos.longitude));
      if (pos.accuracy <= 100) {
        _warmUpSub?.cancel();
        _warmUpSub = null;
      }
    });
  }

  Future<void> _persistTripStart(DateTime startTime) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('trip_start_ms', startTime.millisecondsSinceEpoch);
  }

  Future<void> _clearPersistedTripStart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('trip_start_ms');
  }

  @override
  void dispose() {
    _busSub?.cancel();
    _locSvc.dispose();
    _gpsSub?.cancel();
    _compassSub?.cancel();
    _etaTimer?.cancel();
    _markerAnim?.stop();
    _markerAnim = null;
    _warmUpSub?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  // ══════════════════════════════════════
  // TRIP
  // ══════════════════════════════════════
  Future<void> _startTrip(Bus bus) async {
    if (_processing) return;
    setState(() => _processing = true);
    try {
      if (!_permissionGranted) {
        await _locSvc.checkAndRequestPermissions();
      }
      _warmUpSub?.cancel();
      _warmUpSub = null;

      final depLat = bus.departureLat;
      final depLng = bus.departureLng;
      final arrLat = bus.arrivalLat;
      final arrLng = bus.arrivalLng;
      if (depLat == null || depLng == null || arrLat == null || arrLng == null) {
        throw Exception('Coordonnées de la ligne manquantes.');
      }

      await _busSvc.startTrip(bus.busId);
      await _locSvc.startTracking(bus.busId);

      _depLat = depLat; _depLng = depLng;
      _arrLat = arrLat; _arrLng = arrLng;

      setState(() { _tripActive = true; _processing = false; });
      _tripStartTime  = DateTime.now();
      _initialDistKm  = null;
      _accumulatedDistKm = 0.0;
      _lastDistPos = null;
      _persistTripStart(_tripStartTime!);

      _startGPS(bus.busId);
      _loadRoute();
      _fetchPreRoute();
      _etaTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchETA());
      WakelockPlus.enable();

      _showSnack('Trajet démarré !', _green);

      try {
        NotifyService.notifyOwnerTripStarted(
            ownerId: bus.ownerId, lineName: bus.lineName, busName: bus.busName);
      } catch (_) {}
    } catch (e) {
      if (mounted) { setState(() => _processing = false); _showSnack(e.toString(), _red); }
    }
  }

  Future<void> _stopTrip(Bus bus, {required double recette}) async {
    if (_processing) return;
    setState(() => _processing = true);
    try {
      _gpsSub?.cancel(); _compassSub?.cancel(); _etaTimer?.cancel();
      _markerAnim?.stop(); _markerAnim = null;
      _clearPersistedTripStart();

      await _locSvc.stopTracking(bus.busId);
      WakelockPlus.disable();
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

      final duration    = _tripStartTime != null ? DateTime.now().difference(_tripStartTime!) : Duration.zero;
      final traveledKm  = _accumulatedDistKm;
      final durationHours = duration.inSeconds > 0 ? duration.inSeconds / 3600.0 : 0.0;
      final avgSpeed    = (traveledKm > 0 && durationHours > 0) ? traveledKm / durationHours : 0.0;

      double fuelCostDA = 0.0;
      double fuelLiters = 0.0;
      if (traveledKm > 0) {
        final speedFactor = avgSpeed < 30  ? 1.30
            : avgSpeed < 50  ? 1.10
            : avgSpeed < 80  ? 1.00
            : avgSpeed < 100 ? 1.05
            :                  1.20;
        const baseL100   = 35.0;
        const refMass    = 12000.0;
        final poidsKg    = bus.weightKg?.toDouble() ?? 12000.0;
        final massFactor = (poidsKg / refMass).clamp(0.6, 2.5);
        fuelCostDA = traveledKm * baseL100 * massFactor * speedFactor / 100.0 * 36.0;
        fuelLiters = fuelCostDA / 36.0;
      }

      try {
        await FirebaseFirestore.instance.collection('trips').add({
          'busId':        bus.busId,
          'busName':      bus.busName,
          'lineName':     bus.lineName,
          'departure':    bus.isReversed && bus.lineName.contains('-')
              ? bus.lineName.split('-').last.trim()
              : bus.lineName.split('-').first.trim(),
          'arrival':      bus.isReversed && bus.lineName.contains('-')
              ? bus.lineName.split('-').first.trim()
              : bus.lineName.split('-').last.trim(),
          'driverId':     bus.driverId,
          'ownerId':      bus.ownerId,
          'durationHours': durationHours,
          'distanceKm':   traveledKm,
          'recette':      recette,
          'fuelCostDA':   fuelCostDA,
          'fuelLiters':   fuelLiters,
          'timestamp':    FieldValue.serverTimestamp(),
        });
      } catch (e) { debugPrint('Erreur lors de la sauvegarde du trajet: $e'); }

      // Compute the next trip state before any async operation so it is
      // always applied to _bus even if the Firestore write fails.
      final nextIndex = bus.currentTripIndex + 1;
      final nextBus = bus.copyWith(
        driverStatus: 'online',
        currentTripIndex: nextIndex,
        departureLat: _arrLat ?? bus.departureLat,
        departureLng: _arrLng ?? bus.departureLng,
        arrivalLat:   _depLat ?? bus.arrivalLat,
        arrivalLng:   _depLng ?? bus.arrivalLng,
      );

      // Single atomic write: status + trip progression in one shot so _busSub
      // never fires with a partial state (old coords + new status).
      try {
        final busUpdate = <String, dynamic>{
          'driverStatus': 'online',
          'currentTripIndex': nextIndex,
        };
        if (_depLat != null && _depLng != null && _arrLat != null && _arrLng != null) {
          busUpdate['departureLat'] = _arrLat;
          busUpdate['departureLng'] = _arrLng;
          busUpdate['arrivalLat']   = _depLat;
          busUpdate['arrivalLng']   = _depLng;
        }
        await FirebaseFirestore.instance.collection('buses').doc(bus.busId).update(busUpdate);

        // Safety net: batch-cancel waiting bookings + complete boarded bookings
        // (Cloud Function also does this, but this covers immediate local feedback)
        try {
          final bookingsRef = FirebaseFirestore.instance.collection('bookings');
          final batchOp = FirebaseFirestore.instance.batch();
          final waitingSnap = await bookingsRef
              .where('busId', isEqualTo: bus.busId)
              .where('status', whereIn: ['waiting', 'pending', 'confirmed'])
              .get();
          for (final doc in waitingSnap.docs) {
            batchOp.update(doc.reference, {'status': 'cancelled'});
          }
          final boardedSnap = await bookingsRef
              .where('busId', isEqualTo: bus.busId)
              .where('status', isEqualTo: 'boarded')
              .get();
          for (final doc in boardedSnap.docs) {
            batchOp.update(doc.reference, {'status': 'completed'});
          }
          if (waitingSnap.docs.isNotEmpty || boardedSnap.docs.isNotEmpty) {
            await batchOp.commit();
          }
        } catch (e) { debugPrint('Erreur mise à jour réservations: $e'); }

        _bus = nextBus;
        _tripsCompleted++;
        setState(() {
          _tripActive    = false; _processing = false;
          _fullRoute     = []; _doneRoute = []; _leftRoute = []; _preRoute = [];
          _preRouteLoaded = false; _tripStartTime = null; _initialDistKm = null;
          _warmPos = null; _gotFirstFix = false;
        });
        _preWarmGPS();
      } catch (e) { debugPrint('Erreur fin de trajet: $e'); }

      try {
        NotifyService.notifyOwnerTripEnded(
            ownerId: bus.ownerId,
            lineName: bus.lineName,
            busName: bus.busName,
            recette: recette);
      } catch (_) {}

      if (mounted) _showTripSummary(distKm: traveledKm, duration: duration, avgSpeedKmh: avgSpeed);
    } catch (e) {
      if (mounted) { setState(() => _processing = false); _showSnack(e.toString(), _red); }
    }
  }

  void _showTripSummary({required double distKm, required Duration duration, required double avgSpeedKmh}) {
    final h            = duration.inHours;
    final m            = duration.inMinutes.remainder(60);
    final durationText = h > 0 ? '${h}h ${m}min' : '$m min';
    final distText     = '${distKm.toStringAsFixed(1)} km';
    final speedText    = '${avgSpeedKmh.toStringAsFixed(0)} km/h';

    showModalBottomSheet(
      context: context, isDismissible: true, enableDrag: true,
      backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: ctx.appCardBg,
          borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).padding.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: ctx.appBorder, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Container(width: 56, height: 56,
              decoration: BoxDecoration(color: ctx.appGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16)),
              child: Icon(Icons.check_circle_rounded, color: ctx.appGreen, size: 32)),
          const SizedBox(height: 16),
          Text('Trajet terminé !',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ctx.appDark)),
          const SizedBox(height: 4),
          Text('Résumé de votre trajet',
              style: TextStyle(fontSize: 13, color: ctx.appSub)),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: _SummaryTile(Icons.route_rounded, distText, 'Distance')),
            const SizedBox(width: 12),
            Expanded(child: _SummaryTile(Icons.timer_rounded, durationText, 'Durée')),
            const SizedBox(width: 12),
            Expanded(child: _SummaryTile(Icons.speed_rounded, speedText, 'Vitesse moy.')),
          ]),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                    backgroundColor: ctx.appPrimary, foregroundColor: Colors.white, elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: const Text('Fermer',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              )),
        ]),
      ),
    );
  }

  void _showRecetteDialog(Bus bus) {
    if (_processing) return;
    final recetteCtrl = TextEditingController();
    bool isSubmitting  = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: BoxDecoration(
            color: ctx.appCardBg,
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24), topRight: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: ctx.appBorder, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Container(width: 56, height: 56,
                decoration: BoxDecoration(color: ctx.appPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16)),
                child: Icon(Icons.attach_money_rounded, color: ctx.appPrimary, size: 32)),
            const SizedBox(height: 16),
            Text('Recette du trajet',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ctx.appDark)),
            const SizedBox(height: 4),
            Text('Entrez le montant de la recette pour ce trajet.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: ctx.appSub)),
            const SizedBox(height: 24),
            TextField(
              controller: recetteCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Montant (DZD)',
                prefixIcon: Icon(Icons.account_balance_wallet_rounded, color: ctx.appPrimary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: ctx.appPrimary, width: 2)),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : () {
                    final value = double.tryParse(recetteCtrl.text.replaceAll(',', '.'));
                    if (value == null || value < 0) {
                      _showSnack('Veuillez entrer un montant valide', _red);
                      return;
                    }
                    setSheetState(() => isSubmitting = true);
                    Navigator.pop(ctx);
                    _stopTrip(bus, recette: value);
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: ctx.appGreen, foregroundColor: Colors.white, elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: isSubmitting
                      ? const SizedBox(width: 24, height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Confirmer et terminer',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                )),
          ]),
        ),
      ),
    );
  }

  Future<void> _toggleOnline(Bus bus) async {
    if (_tripActive) return;
    final goOnline = bus.driverStatus == 'offline';
    setState(() => _onlineOptimistic = goOnline);
    try {
      if (goOnline) {
        await _busSvc.goOnline(bus.busId);
      } else {
        await _busSvc.goOffline(bus.busId);
      }
    } catch (_) {
      // revert on error
    } finally {
      if (mounted) setState(() => _onlineOptimistic = null);
    }
  }

  void _showSnack(String msg, Color c) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg), backgroundColor: c,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16), duration: const Duration(seconds: 2)));
  }

  // ══════════════════════════════════════
  // GPS
  // ══════════════════════════════════════
  void _startGPS(String busId) {
    _follow = true;

    if (_warmPos != null && mounted) {
      setState(() {
        _pos = _warmPos!;
        _animPos = _pos;
      });
    }

    _compassSub = FlutterCompass.events?.listen((event) {
      final h = event.heading;
      if (h == null || !mounted) return;
      setState(() => _heading = h);
      if (_follow) _map.moveAndRotate(_adjustedCenter(_pos), _map.camera.zoom, -h);
    });

    _gpsSub = _locSvc.positionStream.listen((p) {
      if (!mounted || !_tripActive) return;
      if (!_gotFirstFix) {
        _gotFirstFix = true;
      } else if (p.accuracy > 50) {
        return;
      }

      double spd  = p.speed < 1.0 ? 0.0 : p.speed;
      final newPos = LatLng(p.latitude, p.longitude);
      final oldPos = _animPos;

      _pos      = newPos;
      _speed    = spd * 3.6;
      _heading  = p.heading;

      _markerAnim?.stop(); _markerAnim = null;
      _markerAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
      _markerAnim!.addListener(() {
        if (!mounted) return;
        final t = Curves.easeInOut.transform(_markerAnim!.value);
        setState(() {
          _animPos = LatLng(
            oldPos.latitude  + (newPos.latitude  - oldPos.latitude)  * t,
            oldPos.longitude + (newPos.longitude - oldPos.longitude) * t,
          );
        });
      });
      _markerAnim!.forward();

      if (_lastDistPos != null) {
        final d = const Distance().as(LengthUnit.Meter, _lastDistPos!, newPos) / 1000.0;
        if (d > 0.01) { // 10 meters min distance to accumulate
          _accumulatedDistKm += d;
          _lastDistPos = newPos;
        }
      } else {
        _lastDistPos = newPos;
      }

      _splitRoute();
      if (_shouldRefreshEta()) _fetchETA();
      if (_follow) _map.moveAndRotate(_adjustedCenter(_pos), _map.camera.zoom, -_heading);
    });
  }

  // ══════════════════════════════════════
  // ROUTE
  // ══════════════════════════════════════
  Future<void> _loadRoute({LatLng? from}) async {
    if ((_depLat == null || _depLng == null) && from == null) return;
    if (_arrLat == null || _arrLng == null) return;
    final startLat = from?.latitude ?? _depLat;
    final startLng = from?.longitude ?? _depLng;
    if (startLat == null || startLng == null) return;
    try {
      final url = Uri.parse(config.getDirectionsUrl(startLng, startLat, _arrLng!, _arrLat!));
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final routes = body['routes'] as List?;
        if (routes == null || routes.isEmpty) return;
        final coords = routes[0]['geometry']['coordinates'] as List;
        final pts = coords.map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList();
        if (mounted && pts.isNotEmpty) setState(() { _fullRoute = pts; _leftRoute = List.from(pts); _doneRoute = []; });
      }
    } catch (_) {
      if (mounted && _fullRoute.isEmpty) {
        _showSnack('Itinéraire indisponible. Vérifiez votre connexion.', _orange);
      }
    } finally {
      if (from != null) _isRerouting = false;
    }
  }

  Future<void> _fetchETA() async {
    if (!_tripActive || _arrLat == null) return;
    try {
      final url = Uri.parse(config.getDirectionsUrl(_pos.longitude, _pos.latitude, _arrLng!, _arrLat!));
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final routes = body['routes'] as List?;
        if (routes == null || routes.isEmpty) return;
        final r = routes[0] as Map<String, dynamic>;
        final arr = DateTime.now().add(Duration(seconds: (r['duration'] as num).round()));
        if (mounted) {
          setState(() {
            _etaMin  = (r['duration'] as num) / 60;
            _distKm  = (r['distance'] as num) / 1000;
            _arrTime = DateFormat('HH:mm').format(arr);
            _lastEtaPos    = _pos;
            _initialDistKm ??= _distKm;
          });
        }
      }
    } catch (_) {}
  }

  void _splitRoute() {
    if (_fullRoute.isEmpty) return;
    double min = double.infinity; int idx = 0;
    const d = Distance();
    for (int i = 0; i < _fullRoute.length; i++) {
      final v = d.as(LengthUnit.Meter, _pos, _fullRoute[i]);
      if (v < min) { min = v; idx = i; }
    }
    if (min > 100) {
      if (!_isRerouting) {
        _isRerouting = true;
        _loadRoute(from: _pos);
      }
    } else {
      if (_preRoute.isNotEmpty) { _preRoute = []; _preRouteLoaded = false; }
      _doneRoute = [..._fullRoute.sublist(0, idx + 1), _pos];
      _leftRoute = [_pos, ..._fullRoute.sublist(idx)];
    }
  }

  Future<void> _fetchPreRoute() async {
    if (_depLat == null || _depLng == null) return;
    _preRouteLoaded = true;
    try {
      final url = Uri.parse(config.getDirectionsUrl(_pos.longitude, _pos.latitude, _depLng!, _depLat!));
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final routes = body['routes'] as List?;
        if (routes == null || routes.isEmpty) return;
        final coords = routes[0]['geometry']['coordinates'] as List;
        final pts = coords.map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList();
        if (mounted && pts.isNotEmpty) setState(() => _preRoute = pts);
      }
    } catch (_) {}
  }

  bool _shouldRefreshEta() =>
      _lastEtaPos == null || const Distance().as(LengthUnit.Meter, _lastEtaPos!, _pos) >= 100;

  LatLng _adjustedCenter(LatLng pos) {
    final screenH  = MediaQuery.sizeOf(context).height;
    final pixelShift = screenH / 2 - 250.0;
    if (pixelShift <= 0) return pos;
    final mpp    = 156543.03392 * cos(pos.latitude * pi / 180) / pow(2, _map.camera.zoom);
    final latDpp = mpp / 111320.0;
    final lngDpp = latDpp / cos(pos.latitude * pi / 180);
    final rad    = _heading * pi / 180.0;
    return LatLng(
      pos.latitude  + cos(rad) * pixelShift * latDpp,
      pos.longitude + sin(rad) * pixelShift * lngDpp,
    );
  }

  // ══════════════════════════════════════
  // SOS
  // ══════════════════════════════════════
  void _showSOS(Bus bus) {
    String? sendingType;
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          Future<void> sendIncident(String type, String label, String msg) async {
            if (sendingType != null) return;
            final confirmed = await showDialog<bool>(
              context: ctx,
              builder: (_) => AlertDialog(
                title: const Text('Confirmer l\'incident', style: TextStyle(fontWeight: FontWeight.w600)),
                content: Text('Signaler "$label" sur cette ligne ?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmer')),
                ],
              ),
            );
            if (confirmed != true) return;
            setSheetState(() => sendingType = type);
            try {
              await FirebaseFirestore.instance.collection('incidents').add({
                'busId': bus.busId, 'lineName': bus.lineName, 'type': type, 'message': msg,
                'latitude': _pos.latitude, 'longitude': _pos.longitude,
                'timestamp': FieldValue.serverTimestamp(), 'ownerId': bus.ownerId,
              });
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) _showSnack('Incident signalé avec succès', _green);
            } catch (e) {
              if (ctx.mounted) setSheetState(() => sendingType = null);
              if (mounted) _showSnack('Erreur : $e', _red);
            }
          }

          return Container(
            decoration: BoxDecoration(
              color: ctx.appCardBg,
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24), topRight: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: ctx.appBorder, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Text('Signaler un incident',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ctx.appDark)),
              const SizedBox(height: 20),
              Row(children: [
                _SOSBtn(Icons.car_crash, 'Accident', _red,
                    sendingType != null ? null : () => sendIncident('accident', 'Accident', 'Accident signalé'),
                    isLoading: sendingType == 'accident'),
                const SizedBox(width: 12),
                _SOSBtn(Icons.schedule, 'Retard', _orange,
                    sendingType != null ? null : () => sendIncident('delay', 'Retard', 'Retard signalé'),
                    isLoading: sendingType == 'delay'),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                _SOSBtn(Icons.build, 'Panne', const Color(0xFF757575),
                    sendingType != null ? null : () => sendIncident('mechanical', 'Panne', 'Panne signalée'),
                    isLoading: sendingType == 'mechanical'),
                const SizedBox(width: 12),
                _SOSBtn(Icons.block, 'Route bloquée', const Color(0xFF212121),
                    sendingType != null ? null : () => sendIncident('road_blocked', 'Route bloquée', 'Route bloquée'),
                    isLoading: sendingType == 'road_blocked'),
              ]),
              SizedBox(height: MediaQuery.of(ctx).padding.bottom + 12),
            ]),
          );
        },
      ),
    );
  }

  void _confirmLogout() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Déconnexion', style: TextStyle(fontWeight: FontWeight.w600)),
      content: const Text('Voulez-vous vraiment vous déconnecter ?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        FilledButton(
          onPressed: () async { Navigator.pop(ctx); _locSvc.dispose(); await _auth.signOut(); },
          style: FilledButton.styleFrom(backgroundColor: ctx.appRed),
          child: const Text('Déconnecter'),
        ),
      ],
    ));
  }

  // ══════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (!_busLoaded) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: context.isDark ? Brightness.light : Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: context.appBg,
          body: Center(child: CircularProgressIndicator(color: context.appPrimary, strokeWidth: 2.5)),
        ),
      );
    }

    if (_bus == null) return _buildNoBus();

    final bus = _bus!;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: context.isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: context.appBg,
        body: Stack(children: [
          if (!_tripActive) _buildNormal(bus),
          if (_tripActive)  _buildDriving(bus),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // NORMAL MODE
  // ══════════════════════════════════════════════════════
  Widget _buildNormal(Bus bus) {
    final top   = MediaQuery.of(context).padding.top;

    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── HEADER (flat, matching transport_app style) ──
        Padding(
          padding: EdgeInsets.fromLTRB(20, top + 16, 20, 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Profile avatar button
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage())),
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                      color: context.appCardBg2.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(14)),
                  child: Icon(Icons.person, color: context.appDark, size: 22),
                ),
              ),
              const SizedBox(width: 12),
               // Brand logo
               Expanded(
                 child: Image.asset(
                   'assets/images/massar_logo.webp',
                   height: 44,
                   fit: BoxFit.contain,
                   alignment: Alignment.centerLeft,
                 ),
               ),
              // Theme toggle
              ValueListenableBuilder<ThemeMode>(
                valueListenable: themeNotifier,
                builder: (_, mode, __) => GestureDetector(
                  onTap: themeNotifier.toggleTheme,
                  child: Container(
                    width: 44, height: 44,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                        color: context.appCardBg2.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(14)),
                    child: Icon(
                        mode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode,
                        color: context.appDark, size: 20),
                  ),
                ),
              ),
              // Logout
              GestureDetector(
                onTap: _confirmLogout,
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                      color: context.appCardBg2.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(14)),
                  child: Icon(Icons.logout, color: context.appDark, size: 20),
                ),
              ),
            ],
          ),
        ),

        // ── BUS INFO CARD ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.appCardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.appBorder),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.directions_bus_rounded, color: context.appPrimary, size: 20),
                const SizedBox(width: 8),
                Text('Mon Bus',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.appDark)),
                const Spacer(),
                _StatusTag(
                  label: bus.driverStatus == 'offline' ? 'Hors ligne' : 'En ligne',
                  color: bus.driverStatus == 'offline' ? context.appSub : context.appGreen,
                ),
              ]),
              const SizedBox(height: 12),
              _InfoRow('Ligne', bus.lineName.isNotEmpty ? bus.displayLineName : 'En attente d\'approbation'),
              const SizedBox(height: 6),
              _InfoRow('Bus', bus.busName.isNotEmpty ? bus.busName : 'N° ${bus.busNumber}'),
            ]),
          ),
        ),
        const SizedBox(height: 14),

        // ── NEXT TRIP CARD ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.appCardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.appBorder),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.route_rounded, color: context.appOrange, size: 20),
                const SizedBox(width: 8),
                Text('Prochain trajet',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.appDark)),
                const Spacer(),
                ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: context.appPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: context.appPrimary.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      bus.tripSchedules.isNotEmpty
                          ? 'Trajet ${(bus.currentTripIndex % bus.tripSchedules.length) + 1}/${bus.tripSchedules.length}'
                          : 'Trajet ${bus.currentTripIndex + 1}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.appPrimary),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                if (bus.nextSchedule != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: context.appOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: context.appOrange.withValues(alpha: 0.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.schedule_rounded, size: 11, color: context.appOrange),
                      const SizedBox(width: 4),
                      Text(
                        bus.nextSchedule!,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.appOrange),
                      ),
                    ]),
                  ),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                // Departure
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Départ', style: TextStyle(fontSize: 11, color: context.appSub)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Container(width: 8, height: 8,
                        decoration: BoxDecoration(color: context.appGreen, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(
                      wilayaNameFromCoords(bus.departureLat, bus.departureLng),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.appDark),
                      overflow: TextOverflow.ellipsis,
                    )),
                  ]),
                ])),
                // Arrow
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward_rounded, size: 18, color: context.appSub),
                ),
                // Arrival
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('Arrivée', style: TextStyle(fontSize: 11, color: context.appSub)),
                  const SizedBox(height: 4),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Expanded(child: Text(
                      wilayaNameFromCoords(bus.arrivalLat, bus.arrivalLng),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.appDark),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    )),
                    const SizedBox(width: 6),
                    Icon(Icons.location_on_rounded, size: 12, color: context.appRed),
                  ]),
                ])),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 14),

        // ── PASSENGERS CARD ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('bookings')
                .where('busId', isEqualTo: bus.busId)
                .where('status', whereIn: ['waiting', 'boarded', 'pending', 'confirmed']).snapshots(),
            builder: (_, snap) {
              final count = snap.data?.docs.length ?? 0;
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.appCardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.appBorder),
                ),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                        color: context.appPrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.people, color: context.appPrimary, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Passagers réservés',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.appDark)),
                    Text('Pour ce trajet',
                        style: TextStyle(fontSize: 11, color: context.appSub)),
                  ])),
                  Text('$count',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: context.appPrimary)),
                ]),
              );
            },
          ),
        ),
        const SizedBox(height: 14),

        // ── ONLINE TOGGLE CARD ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: context.appCardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.appBorder),
            ),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                  bus.driverStatus == 'offline' ? 'Passer en ligne' : 'En ligne',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: context.appDark)),
              subtitle: Text(
                  bus.driverStatus == 'offline' ? 'Pour démarrer un trajet' : 'Visible par les voyageurs',
                  style: TextStyle(fontSize: 11, color: context.appSub)),
              value: _onlineOptimistic ?? (bus.driverStatus != 'offline'),
              onChanged: _tripActive ? null : (_) => _toggleOnline(bus),
              thumbColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected) ? context.appGreen : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),

        // ── START TRIP BUTTON ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(width: double.infinity, height: 60,
            child: ElevatedButton(
              onPressed: (bus.driverStatus == 'offline' || _processing) ? null : () => _startTrip(bus),
              style: ElevatedButton.styleFrom(
                  backgroundColor: context.appGreen, foregroundColor: Colors.white, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  disabledBackgroundColor: context.appBorder),
              child: _processing
                  ? const SizedBox(width: 24, height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.play_arrow_rounded, size: 30),
                      SizedBox(width: 10),
                      Text('Démarrer le trajet',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    ]),
            ),
          ),
        ),
        if (bus.driverStatus == 'offline')
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 20, right: 20),
            child: Text('Passez en ligne d\'abord',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.appOrange, fontSize: 12)),
          ),
        const SizedBox(height: 32),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════
  // DRIVING MODE
  // ══════════════════════════════════════════════════════
  Widget _buildDriving(Bus bus) {
    final double distVal = _distKm ?? (_arrLat != null ? (const Distance().as(LengthUnit.Meter, _pos, LatLng(_arrLat!, _arrLng!)) / 1000.0) : 0.0);
    final double etaVal  = _etaMin ?? (distVal / 30.0 * 60.0);
    final eta    = '${etaVal.round()} min';
    final dist   = '${distVal.toStringAsFixed(1)} km';
    final spd    = '${_speed.round()}';
    final top    = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Stack(children: [
      // ── MAP ──
      ClipRect(
        child: Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0006)
            ..rotateX(-0.30),
          alignment: Alignment.bottomCenter,
          child: Transform.scale(
            scaleX: 1.5, scaleY: 1.4, alignment: Alignment.bottomCenter,
            child: SizedBox.expand(
              child: FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: (_depLat != null && _depLng != null) ? LatLng(_depLat!, _depLng!) : _pos,
                  initialZoom: 17,
                  onPointerDown: (_, __) { if (_follow) setState(() => _follow = false); },
                ),
                children: [
                  TileLayer(
                    urlTemplate: _mapTileUrl,
                    userAgentPackageName: 'com.example.chauffeur_app',
                    tileSize: config.mapTileSize, zoomOffset: config.mapZoomOffset,
                  ),
                  if (_preRoute.length >= 2)
                    PolylineLayer(polylines: [
                      Polyline(points: _preRoute, color: context.appPrimary.withValues(alpha: 0.25), strokeWidth: 10),
                      Polyline(points: _preRoute, color: context.appPrimary.withValues(alpha: 0.5), strokeWidth: 5),
                    ]),
                  if (_doneRoute.length >= 2)
                    PolylineLayer(polylines: [
                      Polyline(points: _doneRoute, color: const Color(0xFFFF9800).withValues(alpha: 0.3), strokeWidth: 14),
                      Polyline(points: _doneRoute, color: const Color(0xFFFF9800), strokeWidth: 7),
                    ]),
                  if (_leftRoute.length >= 2)
                    PolylineLayer(polylines: [
                      Polyline(points: _leftRoute, color: context.appPrimary.withValues(alpha: 0.25), strokeWidth: 14),
                      Polyline(points: _leftRoute, color: context.appPrimary, strokeWidth: 7),
                    ]),
                  MarkerLayer(markers: [
                    if (_depLat != null && _depLng != null)
                      Marker(point: LatLng(_depLat!, _depLng!), width: 14, height: 14,
                          child: Container(decoration: BoxDecoration(
                              color: context.appGreen, shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2)))),
                    if (_arrLat != null)
                      Marker(point: LatLng(_arrLat!, _arrLng!), width: 30, height: 36,
                          child: Icon(Icons.location_on, color: context.appRed, size: 36)),
                    Marker(point: _animPos, width: 80, height: 80,
                      child: Transform.rotate(
                        angle: _heading * 3.14159265 / 180,
                        child: Stack(alignment: Alignment.center, children: [
                          Container(width: 80, height: 80,
                              decoration: BoxDecoration(shape: BoxShape.circle,
                                  color: context.appPrimary.withValues(alpha: 0.13))),
                          Container(width: 56, height: 56, decoration: BoxDecoration(
                              shape: BoxShape.circle, color: Colors.white,
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 12, spreadRadius: 2)])),
                          const Icon(Icons.navigation, color: Color(0xFF4285F4), size: 40),
                        ]),
                      ),
                    ),
                  ]),
                  // Passenger markers
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('bookings')
                        .where('busId', isEqualTo: bus.busId)
                        .where('status', whereIn: ['waiting', 'boarded', 'pending', 'confirmed']).snapshots(),
                    builder: (_, snap) {
                      final docs    = snap.data?.docs ?? [];
                      final markers = <Marker>[];
                      for (final doc in docs) {
                        final d   = doc.data() as Map<String, dynamic>;
                        final lat = (d['passengerLat'] as num?)?.toDouble();
                        final lng = (d['passengerLng'] as num?)?.toDouble();
                        if (lat == null || lng == null) continue;
                        final name = (d['passengerName'] as String?) ?? 'Passager';
                        markers.add(Marker(
                          point: LatLng(lat, lng), width: 80, height: 52,
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: [BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.12), blurRadius: 4)]),
                                child: Text(name.isNotEmpty ? name : 'Passager',
                                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
                                        color: Color(0xFF1A1A1A)),
                                    overflow: TextOverflow.ellipsis)),
                            const SizedBox(height: 2),
                            Container(width: 24, height: 24,
                                decoration: BoxDecoration(color: _orange, shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: [BoxShadow(
                                        color: _orange.withValues(alpha: 0.3), blurRadius: 6)]),
                                child: const Icon(Icons.person, color: Colors.white, size: 14)),
                          ]),
                        ));
                      }
                      if (markers.isEmpty) return const SizedBox();
                      return MarkerLayer(markers: markers);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),

      // ── SPEED BADGE ──
      Positioned(bottom: 140, left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: context.appCardBg, borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8)]),
            child: Column(children: [
              Text(spd, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: context.appDark)),
              Text('km/h', style: TextStyle(fontSize: 10, color: context.appSub)),
            ]),
          )),

      // ── SOS ──
      Positioned(top: top + 70, right: 16,
          child: GestureDetector(
            onTap: () => _showSOS(bus),
            child: Container(width: 48, height: 48,
                decoration: BoxDecoration(color: context.appRed, borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: context.appRed.withValues(alpha: 0.3), blurRadius: 8)]),
                child: const Icon(Icons.warning_rounded, color: Colors.white, size: 24)),
          )),

      // ── RE-CENTER ──
      Positioned(bottom: 140, right: 16,
          child: AnimatedOpacity(
            opacity: _follow ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 350),
            child: IgnorePointer(
              ignoring: _follow,
              child: GestureDetector(
                onTap: () {
                  setState(() => _follow = true);
                  _map.moveAndRotate(_adjustedCenter(_pos), 17, -_heading);
                },
                child: Container(width: 48, height: 48,
                    decoration: BoxDecoration(color: context.appCardBg, shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8)]),
                    child: Icon(Icons.my_location, color: context.appPrimary, size: 22)),
              ),
            ),
          )),

      // ── LINE NAME ──
      Positioned(top: top + 70, left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: context.appCardBg, borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)]),
            child: Text(bus.displayLineName,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.appDark)),
          )),

      // ── ETA BAR (top) ──
      Positioned(top: 0, left: 0, right: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(16, top + 8, 16, 10),
            decoration: BoxDecoration(color: context.appPrimaryDark),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(eta,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
                Text('$dist  ·  Arrivée $_arrTime',
                    style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
              ])),
            ]),
          )),

      // ── END TRIP BAR (bottom) ──
      Positioned(bottom: 0, left: 0, right: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, bottom + 16),
            decoration: BoxDecoration(
                color: context.appCardBg,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8, offset: const Offset(0, -2))]),
            child: SizedBox(height: 52,
                child: ElevatedButton(
                  onPressed: _processing ? null : () => _showRecetteDialog(bus),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: context.appRed, foregroundColor: Colors.white, elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: _processing
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.stop_rounded, size: 28), SizedBox(width: 8),
                          Text('Terminer le trajet',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        ]),
                )),
          )),
    ]);
  }

  Widget _buildNoBus() {
    return Scaffold(
      backgroundColor: context.appBg,
      body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.directions_bus_outlined, size: 64, color: context.appBorder),
        const SizedBox(height: 20),
        Text('Aucun bus assigné',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: context.appDark)),
        const SizedBox(height: 8),
        Text('Le propriétaire n\'a pas encore assigné de bus.',
            textAlign: TextAlign.center, style: TextStyle(color: context.appSub)),
      ])),
    );
  }
}

// ══════════════════════════════════════
// STATUS TAG
// ══════════════════════════════════════
class _StatusTag extends StatelessWidget {
  final String label;
  final Color  color;
  const _StatusTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        color: color.withValues(alpha: 0.07),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

// ══════════════════════════════════════
// INFO ROW
// ══════════════════════════════════════
class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text('$label:', style: TextStyle(fontSize: 13, color: context.appSub)),
      const SizedBox(width: 8),
      Expanded(child: Text(value,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.appDark))),
    ]);
  }
}

// ══════════════════════════════════════
// SOS BUTTON
// ══════════════════════════════════════
class _SOSBtn extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  final VoidCallback? onTap;
  final bool     isLoading;
  const _SOSBtn(this.icon, this.label, this.color, this.onTap, {this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Material(
      color: color.withValues(alpha: onTap == null ? 0.04 : 0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(children: [
            isLoading
                ? SizedBox(width: 24, height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: color))
                : Icon(icon, color: color.withValues(alpha: onTap == null ? 0.4 : 1.0), size: 30),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: color.withValues(alpha: onTap == null ? 0.4 : 1.0))),
          ]),
        ),
      ),
    ));
  }
}

// ══════════════════════════════════════
// SUMMARY TILE
// ══════════════════════════════════════
class _SummaryTile extends StatelessWidget {
  final IconData icon;
  final String   value;
  final String   label;
  const _SummaryTile(this.icon, this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: context.appBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(children: [
        Icon(icon, color: context.appPrimary, size: 22),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.appDark)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(fontSize: 10, color: context.appSub), textAlign: TextAlign.center),
      ]),
    );
  }
}
