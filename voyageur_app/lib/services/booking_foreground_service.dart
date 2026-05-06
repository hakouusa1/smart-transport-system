import 'dart:async';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/booking_model.dart';
import '../models/bus_model.dart';
import 'booking_service.dart';
import 'bus_service.dart';
import 'location_service.dart';
import 'notification_service.dart';

/// Foreground task callback — runs in the background isolate.
/// This is the entry point that flutter_foreground_task calls.
@pragma('vm:entry-point')
void bookingMonitorCallback() {
  FlutterForegroundTask.setTaskHandler(BookingMonitorTaskHandler());
}

class BookingMonitorTaskHandler extends TaskHandler {
  StreamSubscription<Booking?>? _bookingSub;
  StreamSubscription<BusLocation?>? _busLocSub;
  StreamSubscription<Bus?>? _busDocSub;
  StreamSubscription<Position>? _userPosSub;

  Booking? _currentBooking;
  Bus? _currentBus;
  BusLocation? _busLocation;
  Position? _userPosition;

  DateTime? _boardingMatchStart;
  bool _boardingNotified = false;
  bool _busWasNearUser = false;
  bool _busPassedNotified = false;

  static const double _boardingDistanceM = 30.0;
  static const double _speedMatchThresholdKmh = 15.0;
  static const int _boardingDurationSeconds = 20;
  static const double _busNearThresholdM = 50.0;
  static const double _busPassedThresholdM = 200.0;

  final BookingService _bookingService = BookingService();
  final LocationService _locationService = LocationService();
  final BusService _busService = BusService();

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    final busId = await FlutterForegroundTask.getData<String>(key: 'busId');
    if (busId == null || busId.isEmpty) return;

    _startMonitoringForBus(busId);
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    // Periodic check is handled by the streams, but we update the notification
    final status = _currentBooking?.status ?? 'waiting';
    final lineName = _currentBooking?.lineName ?? '';
    FlutterForegroundTask.updateService(
      notificationText: _statusNotificationText(status, lineName),
    );
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    _cleanup();
  }

  @override
  void onNotificationPressed() {
    // No-op in background isolate
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'cancel') {
      if (_currentBooking != null) {
        _bookingService.cancelBooking(_currentBooking!.bookingId);
      }
      FlutterForegroundTask.stopService();
    }
  }

  void _startMonitoringForBus(String busId) {
    // Watch booking
    _bookingSub = _bookingService.getMyBooking(busId).listen((b) {
      if (b == null || !b.isActive) {
        FlutterForegroundTask.stopService();
        return;
      }
      _currentBooking = b;
    });

    // Watch bus location
    _busLocSub = _locationService.getBusLocationStream(busId).listen((loc) {
      _busLocation = loc;
      _checkProximity();
    });

    // Watch bus doc for trip end
    _busDocSub = _busService.getBusById(busId).listen((bus) {
      if (bus == null) {
        FlutterForegroundTask.stopService();
        return;
      }
      final wasOnTrip = _currentBus?.isOnTrip ?? true;
      _currentBus = bus;
      if (wasOnTrip && !bus.isOnTrip) {
        _onTripEnded();
      }
    });

    // Watch user position
    _initUserPosition();
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

    // Boarding detection
    if (distanceM <= _boardingDistanceM) {
      final userSpeedKmh = (_userPosition!.speed < 0.5 ? 0.0 : _userPosition!.speed) * 3.6;
      final busSpeedKmh = _busLocation!.speedKmh;
      final speedDiff = (userSpeedKmh - busSpeedKmh).abs();

      if (speedDiff <= _speedMatchThresholdKmh) {
        final now = DateTime.now();
        _boardingMatchStart ??= now;
        final elapsed = now.difference(_boardingMatchStart!).inSeconds;
        if (elapsed >= _boardingDurationSeconds && !_boardingNotified) {
          _onBoarded();
        }
      } else {
        _boardingMatchStart = null;
      }
    } else {
      _boardingMatchStart = null;
    }

    // Bus-passed detection
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
        id: 30,
      );
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
        id: 31,
      );
      FlutterForegroundTask.stopService();
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
          id: 32,
        );
      } else if (_currentBooking!.isWaiting || _currentBooking!.isPending || _currentBooking!.isConfirmed) {
        await _bookingService.cancelBooking(_currentBooking!.bookingId);
        NotificationService.showNotification(
          title: '🚫 Trajet terminé',
          body: 'Le trajet ${_currentBooking!.busName.isNotEmpty ? _currentBooking!.busName : _currentBooking!.lineName} est terminé. Réservation annulée.',
          id: 33,
        );
      }
      FlutterForegroundTask.stopService();
    } catch (_) {}
  }

  String _statusNotificationText(String status, String lineName) {
    switch (status) {
      case 'boarded':
        return 'Vous êtes à bord de $lineName';
      case 'waiting':
      case 'pending':
      case 'confirmed':
        return 'En attente du bus $lineName...';
      default:
        return 'Suivi de réservation';
    }
  }

  void _cleanup() {
    _bookingSub?.cancel();
    _busLocSub?.cancel();
    _busDocSub?.cancel();
    _userPosSub?.cancel();
    _currentBooking = null;
    _currentBus = null;
    _busLocation = null;
    _userPosition = null;
  }
}

/// Helper class to start/stop the foreground booking monitor from the UI.
class BookingForegroundManager {
  static bool _isRunning = false;

  static bool get isRunning => _isRunning;

  /// Start foreground monitoring for a booking.
  static Future<void> start(String busId, String lineName) async {
    if (_isRunning) return;

    await FlutterForegroundTask.requestNotificationPermission();

    final taskOptions = ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(5000),
      autoRunOnBoot: false,
      autoRunOnMyPackageReplaced: false,
      allowWakeLock: false,
    );

    final androidNotificationOptions = AndroidNotificationOptions(
      channelId: 'booking_monitor',
      channelName: 'Suivi de réservation',
      channelDescription: 'Suivi en arrière-plan de votre réservation de bus',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
    );

    final iosNotificationOptions = const IOSNotificationOptions(
      showNotification: true,
      playSound: false,
    );

    FlutterForegroundTask.init(
      androidNotificationOptions: androidNotificationOptions,
      iosNotificationOptions: iosNotificationOptions,
      foregroundTaskOptions: taskOptions,
    );

    await FlutterForegroundTask.saveData(key: 'busId', value: busId);

    await FlutterForegroundTask.startService(
      serviceId: 500,
      notificationTitle: '🚌 Suivi de réservation',
      notificationText: 'En attente du bus $lineName...',
      notificationButtons: [
        const NotificationButton(id: 'cancel', text: 'Annuler'),
      ],
      callback: bookingMonitorCallback,
    );

    _isRunning = true;
  }

  static Future<void> stop() async {
    if (!_isRunning) return;
    await FlutterForegroundTask.stopService();
    _isRunning = false;
  }
}
