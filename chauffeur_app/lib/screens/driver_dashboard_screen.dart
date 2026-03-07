import 'package:flutter/material.dart';
import '../models/bus_model.dart';
import '../services/auth_service.dart';
import '../services/bus_service.dart';
import '../services/location_service.dart';
import '../widgets/status_badge.dart';
import 'map_screen.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  final _authService = AuthService();
  final _busService = BusService();
  final _locationService = LocationService();

  bool _isTripActive = false;
  bool _isProcessing = false;

  @override
  void dispose() {
    _locationService.dispose();
    super.dispose();
  }

  Future<void> _startTrip(Bus bus) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      await _locationService.checkAndRequestPermissions();
      await _busService.startTrip(bus.busId);
      await _locationService.startTracking(bus.busId);

      setState(() => _isTripActive = true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Trajet démarré ! Envoi de la position GPS...'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _stopTrip(Bus bus) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      await _locationService.stopTracking(bus.busId);
      await _busService.endTrip(bus.busId);

      setState(() => _isTripActive = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Trajet terminé.'),
            backgroundColor: Colors.orange.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _toggleOnlineStatus(Bus bus) async {
    if (_isTripActive) return;

    try {
      if (bus.driverStatus == 'offline') {
        await _busService.goOnline(bus.busId);
      } else {
        await _busService.goOffline(bus.busId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              _locationService.dispose();
              await _authService.signOut();
            },
            child: const Text('Déconnecter'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = _authService.currentUser?.email ?? 'Chauffeur';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de bord'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Déconnexion',
            onPressed: _confirmLogout,
          ),
        ],
      ),
      body: StreamBuilder<Bus?>(
        stream: _busService.getAssignedBus(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          final bus = snapshot.data;

          if (bus == null) {
            return _buildNoBusState(userEmail);
          }

          return _buildDashboard(bus, userEmail);
        },
      ),
    );
  }

  Widget _buildDashboard(Bus bus, String userEmail) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor:
                    Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(
                      Icons.person,
                      size: 28,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bienvenue !',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userEmail,
                          style: TextStyle(color: Colors.grey.shade600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(
                    status: _isTripActive ? 'on_trip' : bus.driverStatus,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Bus info card
          Text(
            'Mon Bus',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.route,
                    label: 'Ligne',
                    value: bus.lineName,
                  ),
                  const SizedBox(height: 10),
                  _InfoRow(
                    icon: Icons.directions_bus,
                    label: 'Bus',
                    value: bus.busName.isNotEmpty
                        ? bus.busName
                        : 'Bus ${bus.busNumber}',
                  ),
                  const SizedBox(height: 10),
                  _InfoRow(
                    icon: Icons.confirmation_number_outlined,
                    label: 'Numéro',
                    value: bus.busNumber,
                  ),
                  const SizedBox(height: 10),
                  _InfoRow(
                    icon: Icons.circle,
                    label: 'Statut',
                    value: bus.statusText,
                    valueColor: bus.isOnTrip
                        ? Colors.blue
                        : bus.isOnline
                        ? Colors.green
                        : Colors.grey,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Online/Offline toggle
          Text(
            'Contrôles',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              title: Text(
                bus.driverStatus == 'offline' ? 'Hors ligne' : 'En ligne',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                bus.driverStatus == 'offline'
                    ? 'Passez en ligne pour démarrer un trajet'
                    : 'Vous êtes visible par les voyageurs',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              value: bus.driverStatus != 'offline',
              onChanged: _isTripActive ? null : (_) => _toggleOnlineStatus(bus),
              activeColor: Colors.green,
              secondary: Icon(
                bus.driverStatus == 'offline'
                    ? Icons.wifi_off
                    : Icons.wifi,
                color: bus.driverStatus == 'offline'
                    ? Colors.grey
                    : Colors.green,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Trip controls
          if (!_isTripActive) ...[
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: (bus.driverStatus == 'offline' || _isProcessing)
                    ? null
                    : () => _startTrip(bus),
                icon: _isProcessing
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.play_arrow_rounded, size: 28),
                label: const Text(
                  'Démarrer le trajet',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            if (bus.driverStatus == 'offline')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Passez en ligne pour démarrer un trajet',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ] else ...[
            // Active trip
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.gps_fixed, color: Colors.blue.shade700),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Trajet en cours',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Position GPS envoyée toutes les 4 secondes',
                          style: TextStyle(
                            color: Colors.blue.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // View map
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MapScreen(busId: bus.busId),
                    ),
                  );
                },
                icon: const Icon(Icons.map_outlined),
                label: const Text(
                  'Voir la carte',
                  style: TextStyle(fontSize: 15),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Stop trip
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : () => _stopTrip(bus),
                icon: _isProcessing
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(Icons.stop_rounded, size: 28),
                label: const Text(
                  'Arrêter le trajet',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildNoBusState(String userEmail) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_bus_outlined, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 20),
            Text(
              'Aucun bus assigné',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            Text(
              'Le propriétaire n\'a pas encore assigné de bus à votre compte.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text('Erreur de chargement', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade500),
        const SizedBox(width: 10),
        Text('$label: ', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
        Expanded(
          child: Text(value,
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: valueColor)),
        ),
      ],
    );
  }
}