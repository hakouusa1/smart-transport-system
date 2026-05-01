import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/price_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bus_loading_indicator.dart';
import '../l10n/app_localizations.dart';

class PriceCalculationScreen extends StatefulWidget {
  final String lineId;
  final String lineName;

  const PriceCalculationScreen({
    super.key,
    required this.lineId,
    required this.lineName,
  });

  @override
  State<PriceCalculationScreen> createState() => _PriceCalculationScreenState();
}

class _PriceCalculationScreenState extends State<PriceCalculationScreen> {
  List<Map<String, dynamic>> _stops = [];
  bool _loadingStops = true;
  String? _selectedDeparture;
  String? _selectedDestination;
  PriceCalculationResult? _priceResult;
  bool _calculatingPrice = false;
  String? _error;
  String? _loadStopsError;

  @override
  void initState() {
    super.initState();
    _loadStops();
  }

  Future<void> _loadStops() async {
    try {
      final lineStopsSnap = await FirebaseFirestore.instance
          .collection('lines')
          .doc(widget.lineId)
          .collection('lineStops')
          .orderBy('orderIndex')
          .get();

      final lineStops = lineStopsSnap.docs.map((doc) => doc.data()).toList();
      final stopIds = lineStops.map((s) => s['stopId'] as String).toList();

      final stopNames = <String, String>{};
      if (stopIds.isNotEmpty) {
        for (var i = 0; i < stopIds.length; i += 30) {
          final chunk = stopIds.sublist(
            i,
            i + 30 > stopIds.length ? stopIds.length : i + 30,
          );
          final snap = await FirebaseFirestore.instance
              .collection('stops')
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
          for (final doc in snap.docs) {
            stopNames[doc.id] = (doc.data()['name'] as String?) ?? doc.id;
          }
        }
      }

      final stopsWithNames = lineStops.map((stop) {
        final stopId = stop['stopId'] as String;
        return {
          'id': stopId,
          'name': stopNames[stopId] ?? stopId,
          'orderIndex': stop['orderIndex'] as int,
        };
      }).toList();

      if (!mounted) return;
      setState(() {
        _stops = stopsWithNames;
        _loadingStops = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadStopsError = context.tr.errorLoadingStops;
        _loadingStops = false;
      });
    }
  }

  Future<void> _calculatePrice() async {
    if (_selectedDeparture == null || _selectedDestination == null) return;

    setState(() {
      _calculatingPrice = true;
      _error = null;
      _priceResult = null;
    });

    try {
      final result = await PriceService.calculatePrice(
        lineId: widget.lineId,
        departureStopId: _selectedDeparture!,
        destinationStopId: _selectedDestination!,
      );
      if (!mounted) return;
      setState(() {
        _priceResult = result;
        _calculatingPrice = false;
      });
    } on PriceCalculationException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _mapErrorCode(e.code);
        _calculatingPrice = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = context.tr.error;
        _calculatingPrice = false;
      });
    }
  }

  String _mapErrorCode(String code) {
    final tr = context.tr;
    switch (code) {
      case 'missing_segment_price':
        return tr.errPriceMissingSegment;
      case 'departure_after_destination':
        return tr.errPriceDepartureAfterDestination;
      case 'departure_not_in_line':
        return tr.errPriceDepartureNotInLine;
      case 'destination_not_in_line':
        return tr.errPriceDestinationNotInLine;
      default:
        return tr.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        title: Text(tr.priceTitle(widget.lineName)),
        backgroundColor: context.appBg,
        elevation: 0,
        iconTheme: IconThemeData(color: context.appText),
      ),
      body: _loadingStops
          ? Center(child: BusLoadingIndicator(color: context.appPrimary))
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    final tr = context.tr;
    if (_loadStopsError != null && _stops.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 48, color: context.appRed),
            const SizedBox(height: 16),
            Text(_loadStopsError!, style: TextStyle(color: context.appRed)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStopSelector(tr.departurePoint, _selectedDeparture, (value) {
            setState(() {
              _selectedDeparture = value;
              _priceResult = null;
              _error = null;
            });
          }),
          const SizedBox(height: 16),
          _buildStopSelector(tr.arrivalPoint, _selectedDestination, (value) {
            setState(() {
              _selectedDestination = value;
              _priceResult = null;
              _error = null;
            });
          }),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: (_selectedDeparture != null &&
                    _selectedDestination != null &&
                    !_calculatingPrice)
                ? _calculatePrice
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.appPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _calculatingPrice
                ? BusLoadingIndicator(
                    color: Theme.of(context).colorScheme.onPrimary, strokeWidth: 2)
                : Text(tr.computePriceBtn,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary, fontSize: 16)),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.appRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: context.appRed.withValues(alpha: 0.3)),
              ),
              child: Text(_error!, style: TextStyle(color: context.appRed)),
            ),
          ],
          if (_priceResult != null) ...[
            const SizedBox(height: 24),
            _buildPriceResult(),
          ],
        ],
      ),
    );
  }

  Widget _buildStopSelector(
      String label, String? selectedValue, ValueChanged<String?> onChanged) {
    final tr = context.tr;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.appText)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: context.appCardBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.appBorder),
          ),
          child: DropdownButton<String>(
            value: selectedValue,
            hint: Text(tr.selectStop,
                style: TextStyle(color: context.appSub)),
            isExpanded: true,
            underline: const SizedBox.shrink(),
            dropdownColor: context.appCardBg,
            style: TextStyle(color: context.appText),
            items: _stops.map((stop) {
              return DropdownMenuItem<String>(
                value: stop['id'] as String,
                child: Text(stop['name'] as String,
                    style: TextStyle(color: context.appText)),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildPriceResult() {
    final tr = context.tr;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appPrimary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payments_outlined, color: context.appPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${tr.totalPriceLabel}: ${_priceResult!.totalPrice.toStringAsFixed(2)} ${tr.currencyDA}',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.appPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('${tr.segmentBreakdown}:',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.appText)),
          const SizedBox(height: 8),
          ..._priceResult!.segments.map((segment) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${segment.fromName} → ${segment.toName}',
                      style: TextStyle(color: context.appText),
                    ),
                  ),
                  Text(
                    '${segment.price.toStringAsFixed(2)} ${tr.currencyDA}',
                    style: TextStyle(
                        color: context.appPrimary,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
