import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/bus_model.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../widgets/bus_trip_card.dart';
import 'map_screen.dart';

class AllBusesListScreen extends StatelessWidget {
  final List<BusTrip> trips;
  final Map<String, double> linePrices;
  final bool isOnTrip;

  const AllBusesListScreen({
    super.key,
    required this.trips,
    required this.linePrices,
    required this.isOnTrip,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final tr = context.tr;
    final title = isOnTrip ? tr.allOnTripTitle : tr.allOnlineTitle;
    final accentColor = isOnTrip ? context.appGreen : context.appPrimary;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarIconBrightness: context.isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: context.isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: context.appBg,
        body: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20, top + 16, 20, 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.arrow_back, size: 20, color: context.appText),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700, color: context.appText,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${trips.length}',
                      style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700, color: accentColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: trips.length,
                itemBuilder: (context, i) {
                  final trip = trips[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: Duration(milliseconds: 250 + (i * 50).clamp(0, 300)),
                      curve: Curves.easeOutCubic,
                      builder: (ctx, value, child) => Transform.translate(
                        offset: Offset(0, 16 * (1 - value)),
                        child: Opacity(opacity: value, child: child),
                      ),
                      child: BusTripCard(
                        trip: trip,
                        basePrice: linePrices[trip.bus.lineId],
                        isOnTrip: isOnTrip,
                        onTap: isOnTrip
                            ? () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => MapScreen(bus: trip.bus)))
                            : null,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
