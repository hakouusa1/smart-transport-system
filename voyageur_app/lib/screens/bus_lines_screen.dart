import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:voyageur_app/screens/search_screen_page.dart';
import '../models/bus_model.dart';
import '../theme/app_theme.dart';
import 'map_screen.dart';
import 'all_buses_map_screen.dart';

const _gBlue = Color(0xFF4285F4);
const _gGreen = Color(0xFF34A853);
const _gRed = Color(0xFFEA4335);
const _gDark = Color(0xFF202124);
const _gSub = Color(0xFF5F6368);
const _gBorder = Color(0xFFDADCE0);
const _gLight = Color(0xFFF8F9FA);

class BusLinesScreen extends StatelessWidget {
  const BusLinesScreen({super.key});

  void _logout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Déconnexion', style: TextStyle(fontWeight: FontWeight.w600)),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () { Navigator.pop(ctx); FirebaseAuth.instance.signOut(); },
            style: FilledButton.styleFrom(backgroundColor: _gRed, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Déconnecter'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _gLight,
      body: SafeArea(
        child: Column(
          children: [
            // ════════════════════════════════════════
            // HEADER
            // ════════════════════════════════════════
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Column(
                children: [
                  // Title row
                  Row(children: [
                    const Expanded(
                      child: Text('Trouvez votre bus', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: _gDark)),
                    ),
                    _HdrBtn(Icons.map_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AllBusesMapScreen()))),
                    const SizedBox(width: 8),
                    _HdrBtn(Icons.logout_rounded, () => _logout(context)),
                  ]),
                  const SizedBox(height: 14),

                  // Search bar (tappable → opens SearchScreen)
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => const SearchScreen(),
                        transitionsBuilder: (_, anim, __, child) {
                          return FadeTransition(opacity: anim, child: child);
                        },
                        transitionDuration: const Duration(milliseconds: 200),
                      ),
                    ),
                    child: Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: _gLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _gBorder),
                      ),
                      child: Row(children: [
                        const Icon(Icons.search, color: _gSub, size: 20),
                        const SizedBox(width: 10),
                        const Text('Où allez-vous ?', style: TextStyle(fontSize: 14, color: _gSub)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: _gBlue.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
                          child: const Text('Rechercher', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _gBlue)),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Stats
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('buses')
                        .where('isActive', isEqualTo: true).snapshots(),
                    builder: (context, snapshot) {
                      final docs = snapshot.data?.docs ?? [];
                      final total = docs.length;
                      final onTrip = docs.where((d) => (d.data() as Map)['driverStatus'] == 'on_trip').length;
                      return Row(children: [
                        _Chip(Icons.directions_bus, '$total bus actifs', _gBlue),
                        const SizedBox(width: 10),
                        _Chip(Icons.gps_fixed, '$onTrip en trajet', _gGreen),
                      ]);
                    },
                  ),
                ],
              ),
            ),

            // ════════════════════════════════════════
            // BUS GRID (on_trip only)
            // ════════════════════════════════════════
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('buses')
                    .where('isActive', isEqualTo: true)
                    .where('driverStatus', isEqualTo: 'on_trip')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildShimmer();
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.directions_bus_outlined, size: 56, color: _gBorder),
                      const SizedBox(height: 16),
                      const Text('Aucun bus en trajet', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: _gDark)),
                      const SizedBox(height: 8),
                      const Text('Revenez plus tard', style: TextStyle(fontSize: 13, color: _gSub)),
                    ]));
                  }

                  final buses = snapshot.data!.docs.map((doc) => Bus.fromMap(doc.data() as Map<String, dynamic>)).toList();

                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.05),
                    itemCount: buses.length,
                    itemBuilder: (context, index) => _BusCard(
                      bus: buses[index],
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MapScreen(bus: buses[index]))),
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

  Widget _buildShimmer() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.05),
      itemCount: 4,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _gBorder)),
      ),
    );
  }
}

// ════════════════════════════════════════
// BUS CARD
// ════════════════════════════════════════
class _BusCard extends StatelessWidget {
  final Bus bus;
  final VoidCallback onTap;
  const _BusCard({required this.bus, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white, borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: _gBlue.withValues(alpha: 0.3))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 36, height: 36,
                  decoration: BoxDecoration(color: _gBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.directions_bus_rounded, color: _gBlue, size: 18)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: _gGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 4, height: 4, decoration: const BoxDecoration(color: _gGreen, shape: BoxShape.circle)),
                  const SizedBox(width: 3),
                  const Text('En trajet', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: _gGreen)),
                ]),
              ),
            ]),
            const Spacer(),
            Text(bus.lineName, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _gDark, height: 1.2)),
            const SizedBox(height: 2),
            Text(bus.busName.isNotEmpty ? bus.busName : 'N° ${bus.busNumber}',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: _gSub)),
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
        child: Container(width: 38, height: 38,
            decoration: BoxDecoration(color: _gLight, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: _gSub, size: 20)));
  }
}

class _Chip extends StatelessWidget {
  final IconData icon; final String label; final Color color;
  const _Chip(this.icon, this.label, this.color);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color)),
      ]),
    );
  }
}