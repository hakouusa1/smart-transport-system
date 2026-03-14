import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:voyageur_app/screens/search_screen_page.dart';
import '../models/bus_model.dart';
import 'map_screen.dart';
import 'all_buses_map_screen.dart';
import 'my_bookings_screen.dart';

const _primary = Color(0xFF1565C0);
const _primaryDark = Color(0xFF0D47A1);
const _primaryLight = Color(0xFF1976D2);
const _green = Color(0xFF2E7D32);
const _greenLight = Color(0xFF4CAF50);
const _red = Color(0xFFD32F2F);
const _orange = Color(0xFFF57C00);
const _dark = Color(0xFF212121);
const _sub = Color(0xFF757575);
const _border = Color(0xFFE0E0E0);
const _bg = Color(0xFFF5F5F5);

class BusLinesScreen extends StatelessWidget {
  const BusLinesScreen({super.key});

  void _logout(BuildContext context) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Déconnexion', style: TextStyle(fontWeight: FontWeight.w600)),
      content: const Text('Voulez-vous vraiment vous déconnecter ?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        FilledButton(onPressed: () { Navigator.pop(ctx); FirebaseAuth.instance.signOut(); },
            style: FilledButton.styleFrom(backgroundColor: _red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Déconnecter')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light),
      child: Scaffold(
        backgroundColor: _bg,
        body: Column(
          children: [
            // ════════════════════════════════════════
            // BLUE HEADER (matching owner)
            // ════════════════════════════════════════
            Container(
              padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 12, 20, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [_primaryDark, _primaryLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + buttons
                  Row(children: [
                    const Expanded(child: Text('Trouvez votre bus', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white))),
                    _HdrBtn(Icons.bookmark_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyBookingsScreen()))),
                    const SizedBox(width: 8),
                    _HdrBtn(Icons.map_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AllBusesMapScreen()))),
                    const SizedBox(width: 8),
                    _HdrBtn(Icons.logout_rounded, () => _logout(context)),
                  ]),
                  const SizedBox(height: 16),

                  // Search bar (opens SearchScreen)
                  GestureDetector(
                    onTap: () => Navigator.push(context, PageRouteBuilder(
                      pageBuilder: (_, __, ___) => const SearchScreen(),
                      transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
                      transitionDuration: const Duration(milliseconds: 200),
                    )),
                    child: Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                      ),
                      child: Row(children: [
                        Icon(Icons.search, color: Colors.white.withValues(alpha: 0.7), size: 20),
                        const SizedBox(width: 10),
                        Text('Où allez-vous ?', style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.7))),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                          child: const Text('Rechercher', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white)),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Stats
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('buses').where('isActive', isEqualTo: true).snapshots(),
                    builder: (_, snap) {
                      final docs = snap.data?.docs ?? [];
                      final total = docs.length;
                      final onTrip = docs.where((d) => (d.data() as Map)['driverStatus'] == 'on_trip').length;
                      return Row(children: [
                        _StatChip(Icons.directions_bus, '$total bus actifs'),
                        const SizedBox(width: 10),
                        _StatChip(Icons.gps_fixed, '$onTrip en trajet'),
                      ]);
                    },
                  ),
                ],
              ),
            ),

            // ════════════════════════════════════════
            // BUS GRID
            // ════════════════════════════════════════
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('buses')
                    .where('isActive', isEqualTo: true)
                    .where('driverStatus', isEqualTo: 'on_trip')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: _primary, strokeWidth: 2.5));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.directions_bus_outlined, size: 56, color: _border),
                      const SizedBox(height: 16),
                      const Text('Aucun bus en trajet', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: _dark)),
                      const SizedBox(height: 8),
                      const Text('Revenez plus tard', style: TextStyle(fontSize: 13, color: _sub)),
                    ]));
                  }

                  final buses = snapshot.data!.docs.map((doc) => Bus.fromMap(doc.data() as Map<String, dynamic>)).toList();

                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.0),
                    itemCount: buses.length,
                    itemBuilder: (_, i) => _BusCard(bus: buses[i],
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MapScreen(bus: buses[i])))),
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

// ════════════════════════════════════════
// BUS CARD (matching owner ticket style)
// ════════════════════════════════════════
class _BusCard extends StatelessWidget {
  final Bus bus; final VoidCallback onTap;
  const _BusCard({required this.bus, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white, borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: _border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Icon + status
            Row(children: [
              Container(width: 36, height: 36,
                  decoration: BoxDecoration(color: _primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.directions_bus_rounded, color: _primary, size: 18)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _green.withValues(alpha: 0.4)),
                    color: _green.withValues(alpha: 0.06)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 4, height: 4, decoration: const BoxDecoration(color: _green, shape: BoxShape.circle)),
                  const SizedBox(width: 3),
                  const Text('En trajet', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: _green)),
                ]),
              ),
            ]),
            const Spacer(),
            // Route: City ● ● ● City
            Row(children: [
              Expanded(child: Text(bus.lineName.split('-').first.trim(),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _dark),
                  overflow: TextOverflow.ellipsis)),
              ...List.generate(3, (_) => Container(width: 3, height: 3, margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: const BoxDecoration(color: _sub, shape: BoxShape.circle))),
              Expanded(child: Text(bus.lineName.contains('-') ? bus.lineName.split('-').last.trim() : '',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _dark),
                  textAlign: TextAlign.end, overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 4),
            Text(bus.busName.isNotEmpty ? bus.busName : 'N° ${bus.busNumber}',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: _sub)),
          ]),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════
// HELPERS
// ════════════════════════════════════════
class _HdrBtn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap;
  const _HdrBtn(this.icon, this.onTap);
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap,
        child: Container(width: 36, height: 36,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: Colors.white, size: 18)));
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon; final String label;
  const _StatChip(this.icon, this.label);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: Colors.white),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white)),
      ]),
    );
  }
}