import 'package:flutter/material.dart';
import '../models/bus_model.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import 'map_screen.dart';
import 'package:latlong2/latlong.dart';

class SearchResultsPage extends StatefulWidget {
  final String departureLabel;
  final String arrivalLabel;
  final LatLng departureLatLng;
  final LatLng arrivalLatLng;
  final List<Bus> matchedBuses;
  final Map<String, double> linePrices;
  final Map<String, double?> segmentPrices;

  const SearchResultsPage({
    super.key,
    required this.departureLabel,
    required this.arrivalLabel,
    required this.departureLatLng,
    required this.arrivalLatLng,
    required this.matchedBuses,
    required this.linePrices,
    required this.segmentPrices,
  });

  @override
  State<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage> {
  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final top = MediaQuery.of(context).padding.top;

    final allTrips = widget.matchedBuses.expand((b) => b.activeTrips).toList();
    final onTripBuses = allTrips.where((t) => t.isEnTrajet).toList();
    final otherBuses = allTrips.where((t) => !t.isEnTrajet).toList();

    final count = widget.matchedBuses.length;
    final countLabel = count == 1
        ? '1 ${tr.busesFound}'
        : '$count ${tr.busesFoundPlural}';

    return Scaffold(
      backgroundColor: context.appBg,
      body: Column(
        children: [
          // ── Header ──
          Container(
            padding: EdgeInsets.fromLTRB(4, top + 4, 16, 14),
            decoration: BoxDecoration(
              color: context.appCardBg,
              boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: context.isDark ? 0.3 : 0.06),
                blurRadius: 8, offset: const Offset(0, 2),
              )],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: context.appText, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(width: 8, height: 8,
                            decoration: BoxDecoration(color: context.appGreen, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.departureLabel,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.appText),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ]),
                      Padding(
                        padding: const EdgeInsets.only(left: 3),
                        child: Container(width: 2, height: 10, color: context.appBorder),
                      ),
                      Row(children: [
                        Container(width: 8, height: 8,
                            decoration: BoxDecoration(color: context.appRed, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.arrivalLabel,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.appText),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Results ──
          Expanded(
            child: widget.matchedBuses.isEmpty
                ? _buildEmpty(context, tr)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                        child: Text(
                          countLabel,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.appText,
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                          children: [
                            // ── En trajet ──
                            if (onTripBuses.isNotEmpty) ...[
                              _sectionHeader(tr.onTripSectionTitle, onTripBuses.length, context.appGreen, context),
                              const SizedBox(height: 8),
                              ...onTripBuses.map((trip) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _ResultBusCard(
                                  trip: trip,
                                  segmentPrice: widget.segmentPrices[trip.bus.lineId],
                                  basePrice: widget.linePrices[trip.bus.lineId],
                                  onTap: () => Navigator.push(context,
                                      MaterialPageRoute(builder: (_) => MapScreen(bus: trip.bus))),
                                ),
                              )),
                              if (otherBuses.isNotEmpty) const SizedBox(height: 8),
                            ],
                            // ── Prochains départs ──
                            if (otherBuses.isNotEmpty) ...[
                              _sectionHeader(tr.prochainsDepartsTitle, otherBuses.length, context.appPrimary, context),
                              const SizedBox(height: 8),
                              ...otherBuses.map((trip) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _ResultBusCard(
                                  trip: trip,
                                  segmentPrice: widget.segmentPrices[trip.bus.lineId],
                                  basePrice: widget.linePrices[trip.bus.lineId],
                                  onTap: () => Navigator.push(context,
                                      MaterialPageRoute(builder: (_) => MapScreen(bus: trip.bus))),
                                ),
                              )),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, AppLocalizations tr) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_bus_outlined, size: 56, color: context.appBorder),
            const SizedBox(height: 16),
            Text(tr.noBusFound,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: context.appText)),
            const SizedBox(height: 8),
            Text(tr.noBusFoundDesc,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: context.appSub, height: 1.4)),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String label, int count, Color color, BuildContext context) {
    return Row(children: [
      Container(width: 3, height: 14,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.appText)),
      const SizedBox(width: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6),
        ),
        child: Text('$count', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      ),
    ]);
  }
}

// ════════════════════════════════════════
// RESULT BUS CARD
// ════════════════════════════════════════
class _ResultBusCard extends StatelessWidget {
  final BusTrip trip;
  final VoidCallback onTap;
  final double? segmentPrice;
  final double? basePrice;

  const _ResultBusCard({
    required this.trip,
    required this.onTap,
    this.segmentPrice,
    this.basePrice,
  });

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final bus = trip.bus;
    final live = trip.isEnTrajet;
    final statusColor = live ? context.appGreen : context.appPrimary;
    final nextTime = !live ? trip.scheduleTime : null;
    final price = segmentPrice ?? basePrice;

    return Material(
      color: context.appCardBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: live
                  ? context.appGreen.withValues(alpha: 0.35)
                  : context.appBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: live
                        ? context.appGreen.withValues(alpha: 0.1)
                        : context.appPrimary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.directions_bus_rounded,
                      color: live ? context.appGreen : context.appPrimary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(trip.displayLineName,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.appText)),
                    const SizedBox(height: 2),
                    Text(bus.busName.isNotEmpty ? bus.busName : 'N° ${bus.busNumber}',
                        style: TextStyle(fontSize: 11, color: context.appSub)),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                          width: 5, height: 5,
                          decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      Text(live ? tr.onTripDot : tr.onlineDot,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor)),
                    ]),
                  ),
                  const SizedBox(height: 5),
                  if (nextTime != null)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.schedule_rounded, size: 10, color: context.appSub),
                      const SizedBox(width: 3),
                      Text(nextTime,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.appPrimary)),
                    ])
                  else if (live)
                    Icon(Icons.radio_button_checked, size: 14, color: context.appGreen),
                ]),
              ]),

              // Price + see on map
              const SizedBox(height: 10),
              Row(children: [
                if (price != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.appGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.payments_outlined, size: 12, color: context.appGreen),
                      const SizedBox(width: 4),
                      Text(
                        '${price.toStringAsFixed(0)} ${tr.currencyDA}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.appGreen),
                      ),
                    ]),
                  )
                else
                  Text('---', style: TextStyle(fontSize: 12, color: context.appSub)),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.map, size: 15),
                  label: Text(tr.showOnMap),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.appPrimary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
