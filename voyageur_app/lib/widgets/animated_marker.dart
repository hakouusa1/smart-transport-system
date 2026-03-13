import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Smoothly animates a marker position using Tween interpolation
/// Instead of jumping from point A to B, it slides smoothly
class AnimatedMarkerPosition {
  LatLng _current;
  LatLng _target;
  LatLng _previous;

  AnimatedMarkerPosition(LatLng initial)
      : _current = initial,
        _target = initial,
        _previous = initial;

  LatLng get current => _current;
  LatLng get target => _target;
  LatLng get previous => _previous;

  /// Call this when a new GPS position arrives
  void updateTarget(LatLng newTarget) {
    _previous = _current;
    _target = newTarget;
  }

  /// Call this on every animation frame (t goes from 0.0 to 1.0)
  LatLng interpolate(double t) {
    final lat = _previous.latitude + (_target.latitude - _previous.latitude) * t;
    final lng = _previous.longitude + (_target.longitude - _previous.longitude) * t;
    _current = LatLng(lat, lng);
    return _current;
  }
}

/// Widget that smoothly animates a child between two LatLng positions
/// Use this to wrap your bus marker icon
class SmoothMarker extends StatefulWidget {
  final LatLng position;
  final Duration duration;
  final Widget child;
  final void Function(LatLng)? onAnimated; // callback with interpolated position

  const SmoothMarker({
    super.key,
    required this.position,
    this.duration = const Duration(milliseconds: 800),
    required this.child,
    this.onAnimated,
  });

  @override
  State<SmoothMarker> createState() => _SmoothMarkerState();
}

class _SmoothMarkerState extends State<SmoothMarker> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late LatLng _start;
  late LatLng _end;

  @override
  void initState() {
    super.initState();
    _start = widget.position;
    _end = widget.position;
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _controller.addListener(() {
      if (widget.onAnimated != null) {
        final lat = _start.latitude + (_end.latitude - _start.latitude) * _controller.value;
        final lng = _start.longitude + (_end.longitude - _start.longitude) * _controller.value;
        widget.onAnimated!(LatLng(lat, lng));
      }
    });
  }

  @override
  void didUpdateWidget(covariant SmoothMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.position != widget.position) {
      _start = _end;
      _end = widget.position;
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
