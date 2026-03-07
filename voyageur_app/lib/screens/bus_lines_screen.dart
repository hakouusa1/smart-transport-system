import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/bus_model.dart';
import '../theme/app_theme.dart';
import 'map_screen.dart';
import 'all_buses_map_screen.dart';

class BusLinesScreen extends StatefulWidget {
  const BusLinesScreen({super.key});

  @override
  State<BusLinesScreen> createState() => _BusLinesScreenState();
}

class _BusLinesScreenState extends State<BusLinesScreen>
    with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Déconnexion',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
        content: const Text('Voulez-vous vraiment vous déconnecter ?',
            style: TextStyle(fontFamily: 'Poppins')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              FirebaseAuth.instance.signOut();
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Déconnecter'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // ============================================
            // HEADER
            // ============================================
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
                boxShadow: AppTheme.coloredShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bonjour !',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                            Text(
                              'Trouvez votre bus',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Global map button
                      _HeaderButton(
                        icon: Icons.map_rounded,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AllBusesMapScreen()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _HeaderButton(
                        icon: Icons.logout_rounded,
                        onTap: _logout,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Search bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: TextField(
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: const TextStyle(
                          color: Colors.white, fontFamily: 'Poppins'),
                      decoration: InputDecoration(
                        hintText: 'Rechercher une ligne...',
                        hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontFamily: 'Poppins'),
                        prefixIcon: Icon(Icons.search,
                            color: Colors.white.withValues(alpha: 0.6)),
                        border: InputBorder.none,
                        contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Stats row
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('buses')
                        .where('isActive', isEqualTo: true)
                        .where('driverStatus', isEqualTo: 'on_trip')
                        .snapshots(),
                    builder: (context, snapshot) {
                      final buses = snapshot.data?.docs ?? [];
                      final total = buses.length;
                      final onTrip = buses.where((d) {
                        final data = d.data() as Map<String, dynamic>;
                        return data['driverStatus'] == 'on_trip';
                      }).length;

                      return Row(
                        children: [
                          _StatChip(
                            icon: Icons.directions_bus,
                            label: '$total bus actifs',
                            color: Colors.white,
                          ),
                          const SizedBox(width: 12),
                          _StatChip(
                            icon: Icons.gps_fixed,
                            label: '$onTrip en trajet',
                            color: AppTheme.accent,
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            // ============================================
            // BUS LIST
            // ============================================
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('buses')
                    .where('isActive', isEqualTo: true)
                    .where('driverStatus' , isEqualTo: 'on_trip')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildShimmerList();
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildEmptyState();
                  }

                  final buses = snapshot.data!.docs
                      .map((doc) =>
                      Bus.fromMap(doc.data() as Map<String, dynamic>))
                      .where((bus) =>
                  bus.lineName
                      .toLowerCase()
                      .contains(_searchQuery.toLowerCase()) ||
                      bus.busName
                          .toLowerCase()
                          .contains(_searchQuery.toLowerCase()))
                      .toList();

                  if (buses.isEmpty) {
                    return _buildEmptyState(isSearch: true);
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.95,
                    ),
                    itemCount: buses.length,
                    itemBuilder: (context, index) {
                      return _AnimatedBusCard(
                        bus: buses[index],
                        index: index,
                        onTap: () => Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (_, __, ___) =>
                                MapScreen(bus: buses[index]),
                            transitionsBuilder: (_, anim, __, child) {
                              return FadeTransition(
                                opacity: anim,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.05),
                                    end: Offset.zero,
                                  ).animate(CurvedAnimation(
                                    parent: anim,
                                    curve: Curves.easeOut,
                                  )),
                                  child: child,
                                ),
                              );
                            },
                            transitionDuration: const Duration(milliseconds: 300),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // SHIMMER LOADING
  // ============================================
  Widget _buildShimmerList() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ShimmerBox(width: 50, height: 50, borderRadius: 14),
                const SizedBox(height: 12),
                _ShimmerBox(width: 100, height: 12, borderRadius: 6),
                const SizedBox(height: 8),
                _ShimmerBox(width: 70, height: 10, borderRadius: 6),
                const Spacer(),
                _ShimmerBox(width: 80, height: 22, borderRadius: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({bool isSearch = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearch ? Icons.search_off : Icons.directions_bus_outlined,
            size: 64,
            color: AppTheme.mediumGrey,
          ),
          const SizedBox(height: 16),
          Text(
            isSearch ? 'Aucun résultat' : 'Aucun bus disponible',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.darkGrey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isSearch
                ? 'Essayez une autre recherche'
                : 'Revenez plus tard',
            style: const TextStyle(
              fontFamily: 'Poppins',
              color: AppTheme.mediumGrey,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// ANIMATED BUS CARD (Google Maps style)
// ============================================
class _AnimatedBusCard extends StatefulWidget {
  final Bus bus;
  final int index;
  final VoidCallback onTap;

  const _AnimatedBusCard({
    required this.bus,
    required this.index,
    required this.onTap,
  });

  @override
  State<_AnimatedBusCard> createState() => _AnimatedBusCardState();
}

class _AnimatedBusCardState extends State<_AnimatedBusCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    Future.delayed(Duration(milliseconds: 60 * widget.index), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static const _gBlue = Color(0xFF4285F4);
  static const _gGreen = Color(0xFF34A853);
  static const _gSub = Color(0xFF5F6368);
  static const _gDark = Color(0xFF202124);
  static const _gBorder = Color(0xFFE8EAED);

  @override
  Widget build(BuildContext context) {
    final bus = widget.bus;
    final isOnTrip = bus.driverStatus == 'on_trip';
    final isOnline = bus.driverStatus == 'online';

    final statusColor = isOnTrip ? _gBlue : isOnline ? _gGreen : _gSub;
    final statusText = isOnTrip ? 'En trajet' : isOnline ? 'En ligne' : 'Hors ligne';

    return ScaleTransition(
      scale: _scaleAnim,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 0,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isOnTrip ? _gBlue.withValues(alpha: 0.3) : _gBorder, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: icon + status dot
                Row(
                  children: [
                    // Bus icon
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.directions_bus_rounded,
                        color: statusColor,
                        size: 20,
                      ),
                    ),
                    const Spacer(),
                    // Status dot
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5, height: 5,
                            decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 4),
                          Text(statusText,
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: statusColor)),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),

                // Line name
                Text(
                  bus.lineName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _gDark,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),

                // Bus name / number
                Text(
                  bus.busName.isNotEmpty ? bus.busName : 'N° ${bus.busNumber}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: _gSub),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================
// HELPER WIDGETS
// ============================================
class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const _ShimmerBox({
    required this.width,
    required this.height,
    required this.borderRadius,
  });

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              colors: [
                Colors.grey.shade200,
                Colors.grey.shade100,
                Colors.grey.shade200,
              ],
              stops: [
                (_controller.value - 0.3).clamp(0.0, 1.0),
                _controller.value,
                (_controller.value + 0.3).clamp(0.0, 1.0),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        );
      },
    );
  }
}