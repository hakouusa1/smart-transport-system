import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

class PriceCalculationResult {
  final double totalPrice;
  final List<PriceSegment> segments;

  PriceCalculationResult({required this.totalPrice, required this.segments});
}

class PriceSegment {
  final String fromStopId;
  final String toStopId;
  final String fromName;
  final String toName;
  final double price;

  PriceSegment({
    required this.fromStopId,
    required this.toStopId,
    required this.fromName,
    required this.toName,
    required this.price,
  });
}

class PriceCalculationException implements Exception {
  final String code;
  PriceCalculationException(this.code);
  @override
  String toString() => code;
}

class PriceService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<PriceCalculationResult> calculatePrice({
    required String lineId,
    required String departureStopId,
    required String destinationStopId,
  }) async {
    final lineStopsSnap = await _db
        .collection('lines')
        .doc(lineId)
        .collection('lineStops')
        .orderBy('orderIndex')
        .get();

    final stopIds = lineStopsSnap.docs
        .map((d) => d.data()['stopId'] as String)
        .toList();

    final departureIndex = stopIds.indexOf(departureStopId);
    final destinationIndex = stopIds.indexOf(destinationStopId);

    if (departureIndex == -1) {
      throw PriceCalculationException('departure_not_in_line');
    }
    if (destinationIndex == -1) {
      throw PriceCalculationException('destination_not_in_line');
    }
    if (departureIndex >= destinationIndex) {
      throw PriceCalculationException('departure_after_destination');
    }

    final segmentsSnap = await _db
        .collection('lines')
        .doc(lineId)
        .collection('segmentPrices')
        .get();

    final segmentPriceByKey = <String, double>{};
    for (final doc in segmentsSnap.docs) {
      final data = doc.data();
      final key = '${data['fromStopId']}-${data['toStopId']}';
      segmentPriceByKey[key] = (data['price'] as num).toDouble();
    }

    final neededStopIds = stopIds.sublist(departureIndex, destinationIndex + 1).toSet();
    final stopNames = await _fetchStopNames(neededStopIds);

    double totalPrice = 0.0;
    final tripSegments = <PriceSegment>[];
    for (var i = departureIndex; i < destinationIndex; i++) {
      final fromId = stopIds[i];
      final toId = stopIds[i + 1];
      final price = segmentPriceByKey['$fromId-$toId'];
      if (price == null) {
        throw PriceCalculationException('missing_segment_price');
      }
      totalPrice += price;
      tripSegments.add(PriceSegment(
        fromStopId: fromId,
        toStopId: toId,
        fromName: stopNames[fromId] ?? fromId,
        toName: stopNames[toId] ?? toId,
        price: price,
      ));
    }

    return PriceCalculationResult(
      totalPrice: totalPrice,
      segments: tripSegments,
    );
  }

  /// Computes the segment price for a line by snapping the user's lat/lng
  /// pair to the nearest stop on the line and summing segment prices between
  /// them. Returns null when the line has no stops, the snapped indices are
  /// inverted, or any segment price is missing.
  static Future<double?> calculateSegmentPriceForCoords({
    required String lineId,
    required LatLng from,
    required LatLng to,
  }) async {
    final lineStopsSnap = await _db
        .collection('lines')
        .doc(lineId)
        .collection('lineStops')
        .orderBy('orderIndex')
        .get();

    if (lineStopsSnap.docs.isEmpty) return null;

    final stopIds = lineStopsSnap.docs
        .map((d) => d.data()['stopId'] as String)
        .toList();

    final stopsSnap = await _fetchStopsByIds(stopIds.toSet());
    final stopCoords = <String, LatLng>{};
    for (final entry in stopsSnap.entries) {
      final lat = (entry.value['lat'] as num?)?.toDouble();
      final lng = (entry.value['lng'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        stopCoords[entry.key] = LatLng(lat, lng);
      }
    }

    if (stopCoords.isEmpty) return null;

    const dist = Distance();
    int? nearestIndex(LatLng target) {
      int? best;
      double bestDist = double.infinity;
      for (var i = 0; i < stopIds.length; i++) {
        final coord = stopCoords[stopIds[i]];
        if (coord == null) continue;
        final d = dist.as(LengthUnit.Meter, target, coord);
        if (d < bestDist) {
          bestDist = d;
          best = i;
        }
      }
      return best;
    }

    final fromIdx = nearestIndex(from);
    final toIdx = nearestIndex(to);
    if (fromIdx == null || toIdx == null) return null;
    if (fromIdx >= toIdx) return null;

    final segmentsSnap = await _db
        .collection('lines')
        .doc(lineId)
        .collection('segmentPrices')
        .get();

    final segmentPriceByKey = <String, double>{};
    for (final doc in segmentsSnap.docs) {
      final data = doc.data();
      final key = '${data['fromStopId']}-${data['toStopId']}';
      segmentPriceByKey[key] = (data['price'] as num).toDouble();
    }

    double total = 0.0;
    for (var i = fromIdx; i < toIdx; i++) {
      final key = '${stopIds[i]}-${stopIds[i + 1]}';
      final price = segmentPriceByKey[key];
      if (price == null) return null;
      total += price;
    }
    return total;
  }

  static Future<Map<String, Map<String, dynamic>>> _fetchStopsByIds(
      Set<String> ids) async {
    if (ids.isEmpty) return {};
    final result = <String, Map<String, dynamic>>{};
    final list = ids.toList();
    for (var i = 0; i < list.length; i += 30) {
      final chunk = list.sublist(i, i + 30 > list.length ? list.length : i + 30);
      final snap = await _db
          .collection('stops')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        result[doc.id] = doc.data();
      }
    }
    return result;
  }

  static Future<Map<String, String>> _fetchStopNames(Set<String> ids) async {
    if (ids.isEmpty) return {};
    final result = <String, String>{};
    final list = ids.toList();
    // Firestore whereIn supports up to 30 ids per query (v2). Chunk just in case.
    for (var i = 0; i < list.length; i += 30) {
      final chunk = list.sublist(i, i + 30 > list.length ? list.length : i + 30);
      final snap = await _db
          .collection('stops')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        result[doc.id] = (doc.data()['name'] as String?) ?? doc.id;
      }
    }
    return result;
  }
}
