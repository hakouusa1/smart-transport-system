import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/bus_service.dart';
import '../models/bus_model.dart';
import '../theme_notifier.dart';
import 'bus_tracking_screen.dart';
import '../widgets/bus_card.dart';
import '../widgets/bus_loading_indicator.dart';

class _BusTag extends StatelessWidget {
  final String label;
  final Color color;
  const _BusTag(this.label, this.color);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class BusesEnTrajetScreen extends StatelessWidget {
  const BusesEnTrajetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final busService = BusService();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: context.isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: context.appBg,
        appBar: AppBar(
          backgroundColor: context.appBg,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: context.appDark),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Bus en trajet',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: context.appDark),
          ),
          centerTitle: false,
        ),
        body: StreamBuilder<List<Bus>>(
          stream: busService.getBuses(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: BusLoadingIndicator());
            }
            final buses = (snapshot.data ?? [])
                .where((b) => b.driverStatus == 'on_trip')
                .toList();

            if (buses.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.directions_bus_outlined, size: 56, color: context.appBorder),
                    const SizedBox(height: 14),
                    Text('Aucun bus en trajet', style: TextStyle(color: context.appSub, fontSize: 14)),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              itemCount: buses.length,
              itemBuilder: (_, i) {
                final bus = buses[i];
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => BusTrackingScreen(bus: bus)),
                  ),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.appCardBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                bus.lineName.split('-').first.trim(),
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.appDark),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Row(
                                children: List.generate(5, (_) => Container(
                                  width: 4, height: 4,
                                  margin: const EdgeInsets.symmetric(horizontal: 2),
                                  decoration: BoxDecoration(color: context.appSub, shape: BoxShape.circle),
                                )),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                bus.lineName.contains('-') ? bus.lineName.split('-').last.trim() : '',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.appDark),
                                textAlign: TextAlign.end,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          bus.busName.isNotEmpty ? bus.busName : 'N° ${bus.busNumber}',
                          style: TextStyle(fontSize: 11, color: context.appSub),
                        ),
                        const SizedBox(height: 8),
                        RouteThumbnail(bus: bus, height: 110, onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => BusTrackingScreen(bus: bus)));
                        }),
                        const SizedBox(height: 10),
                        Row(children: [
                          _BusTag('En trajet', context.appGreen),
                          const SizedBox(width: 6),
                          if (bus.busNumber.isNotEmpty) _BusTag('N° ${bus.busNumber}', context.appPrimary),
                        ]),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
