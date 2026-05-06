import 'dart:async';
import 'dart:ui';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/booking_model.dart';
import '../models/bus_model.dart';
import 'booking_service.dart';
import 'bus_service.dart';
import 'location_service.dart';
import 'notification_service.dart';

/// Monitors the proximity between the passenger and the booked bus
/// to automatically detect boarding or bus-passed scenarios.
///
/// Lifecycle:
///   waiting → boarded  (user ≤30m from bus + matching speed for 20s)
///   waiting → cancelled (bus was <50m, now 200m+ away, user never matched)
///   boarded → completed (trip ended while user was on board)
class BookingMonitorService {
  final BookingService _bookingService = BookingService();
  final LocationService _locationService = LocationService();
  final BusService _busService = BusService();

  StreamSubscription<Booking?>? _bookingSub;
  StreamSubscription<BusLocation?>? _busLocSub;
  StreamSubscription<Bus?>? _busDocSub;
  StreamSubscription<Position>? _userPosSub;

  Booking? _currentBooking;
  Bus? _currentBus;
  BusLocation? _busLocation;
  Position? _userPosition;

  // Boarding detection state
  DateTime? _boardingMatchStart;
  bool _boardingNotified = false;

  // Bus-passed detection state
  bool _busWasNearUser = false;
  bool _busPassedNotified = false;

  // Callbacks for UI updates
  VoidCallback? onStatusChanged;

  static const double _boardingDistanceM = 30.0;
  static const double _speedMatchThresholdKmh = 15.0;
  static const int _boardingDurationSeconds = 20;
  static const double _busNearThresholdM = 50.0;
  static const double _busPassedThresholdM = 200.0;

  bool get isMonitoring => _bookingSub != null;

  /// Start monitoring for the given booking.
  void startMonitoring(Booking booking) {
    stopMonitoring(); // Clean up any previous session

    _currentBooking = booking;
    _boardingMatchStart = null;
    _boardingNotified = false;
    _busWasNearUser = false;
    _busPassedNotified = false;

    // Watch booking status changes
    _bookingSub = _bookingService.getMyBooking(booking.busId).listen((b) {
      if (b == null || !b.isActive) {
        // Booking was cancelled or completed externally — stop monitoring
        stopMonitoring();
        return;
      }
      _currentBooking = b;
    });

    // Watch bus location
    _busLocSub = _locationService.getBusLocationStream(booking.busId).listen((loc) {
      _busLocation = loc;
      _checkProximity();
    });

    // Watch bus document for trip-end detection
    _busDocSub = _busService.getBusById(booking.busId).listen((bus) {
      if (bus == null) {
        stopMonitoring();
        return;
      }
      final wasOnTrip = _currentBus?.isOnTrip ?? true;
      _currentBus = bus;

      // Trip ended — handle accordingly
      if (wasOnTrip && !bus.isOnTrip) {
        _onTripEnded();
      }
    });

    // Watch user position
    _initUserPosition();
  }

  /// Stop all monitoring streams.
  void stopMonitoring() {
    _bookingSub?.cancel();
    _bookingSub = null;
    _busLocSub?.cancel();
    _busLocSub = null;
    _busDocSub?.cancel();
    _busDocSub = null;
    _userPosSub?.cancel();
    _userPosSub = null;
    _currentBooking = null;
    _currentBus = null;
    _busLocation = null;
    _userPosition = null;
    _boardingMatchStart = null;
    _busWasNearUser = false;
  }

  Future<void> _initUserPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      _userPosition = pos;

      _userPosSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5),
      ).listen((p) {
        _userPosition = p;
        _checkProximity();
      });
    } catch (_) {}
  }

  void _checkProximity() {
    if (_currentBooking == null || _busLocation == null || _userPosition == null) return;
    if (_currentBooking!.isBoarded || _currentBooking!.isCompleted || _currentBooking!.isCancelled) return;

    final userLatLng = LatLng(_userPosition!.latitude, _userPosition!.longitude);
    final busLatLng = _busLocation!.latLng;
    final distanceM = const Distance().as(LengthUnit.Meter, userLatLng, busLatLng);

    // ── Boarding detection ──
    if (distanceM <= _boardingDistanceM) {
      final userSpeedKmh = (_userPosition!.speed < 0.5 ? 0.0 : _userPosition!.speed) * 3.6;
      final busSpeedKmh = _busLocation!.speedKmh;
      final speedDiff = (userSpeedKmh - busSpeedKmh).abs();

      if (speedDiff <= _speedMatchThresholdKmh) {
        // Speed and position match
        final now = DateTime.now();
        if (_boardingMatchStart == null) {
          _boardingMatchStart = now;
        } else {
          final elapsed = now.difference(_boardingMatchStart!).inSeconds;
          if (elapsed >= _boardingDurationSeconds && !_boardingNotified) {
            _onBoarded();
          }
        }
      } else {
        // Speed doesn't match — reset boarding timer
        _boardingMatchStart = null;
      }
    } else {
      // Not close enough — reset boarding timer
      _boardingMatchStart = null;
    }

    // ── Bus-passed detection ──
    if (distanceM < _busNearThresholdM) {
      _busWasNearUser = true;
    }

    if (_busWasNearUser && distanceM > _busPassedThresholdM && !_currentBooking!.isBoarded && !_busPassedNotified) {
      _onBusPassed();
    }
  }

  Future<void> _onBoarded() async {
    _boardingNotified = true;
    if (_currentBooking == null) return;

    try {
      await _bookingService.markAsBoarded(_currentBooking!.bookingId);
      NotificationService.showNotification(
        title: '🚌 Bien à bord !',
        body: 'Vous avez été détecté(e) à bord de ${_currentBooking!.busName.isNotEmpty ? _currentBooking!.busName : _currentBooking!.lineName}.',
        id: 20,
      );
      onStatusChanged?.call();
    } catch (_) {}
  }

  Future<void> _onBusPassed() async {
    _busPassedNotified = true;
    if (_currentBooking == null) return;

    try {
      await _bookingService.cancelBooking(_currentBooking!.bookingId);
      NotificationService.showNotification(
        title: '🚫 Bus déjà passé',
        body: 'Le bus ${_currentBooking!.busName.isNotEmpty ? _currentBooking!.busName : _currentBooking!.lineName} est passé sans vous. Réservation annulée.',
        id: 21,
      );
      onStatusChanged?.call();
      stopMonitoring();
    } catch (_) {}
  }

  Future<void> _onTripEnded() async {
    if (_currentBooking == null) return;

    try {
      if (_currentBooking!.isBoarded) {
        await _bookingService.markAsCompleted(_currentBooking!.bookingId);
        NotificationService.showNotification(
          title: '🏁 Trajet terminé',
          body: 'Votre trajet sur ${_currentBooking!.busName.isNotEmpty ? _currentBooking!.busName : _currentBooking!.lineName} est terminé.',
          id: 22,
        );
      } else if (_currentBooking!.isWaiting || _currentBooking!.isPending || _currentBooking!.isConfirmed) {
        await _bookingService.cancelBooking(_currentBooking!.bookingId);
        NotificationService.showNotification(
          title: '🚫 Trajet terminé',
          body: 'Le trajet ${_currentBooking!.busName.isNotEmpty ? _currentBooking!.busName : _currentBooking!.lineName} est terminé. Réservation annulée.',
          id: 23,
        );
      }
      onStatusChanged?.call();
      stopMonitoring();
    } catch (_) {}
  }
}
