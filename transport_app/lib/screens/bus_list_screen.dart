import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/bus_model.dart';
import '../services/bus_service.dart';
import '../widgets/bus_card.dart';
import 'add_bus_screen.dart';
import 'add_bus_screen.dart';
import '../theme_notifier.dart';
import '../widgets/staggered_list_item.dart';
import '../widgets/bus_loading_indicator.dart';



class BusListScreen extends StatefulWidget {
  final bool showBackButton;
  const BusListScreen({super.key, this.showBackButton = true});

  @override
  State<BusListScreen> createState() => _BusListScreenState();
}

class _BusListScreenState extends State<BusListScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _busService = BusService();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: context.appBg,
        body: StreamBuilder<List<Bus>>(
          stream: _busService.getBuses(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: BusLoadingIndicator(color: context.appPurple, strokeWidth: 2.5));
            }
            if (snapshot.hasError) {
              return Center(child: Text('Erreur: ${snapshot.error}', style: TextStyle(color: context.appSub)));
            }

            final all = snapshot.data ?? [];
            final approved = all.where((b) => b.validationStatus == 'approved').toList();
            final pending = all.where((b) => b.validationStatus == 'pending').toList();
            final rejected = all.where((b) => b.validationStatus == 'rejected').toList();

            return Column(
              children: [
                // ── Header ──
                Container(
                  padding: EdgeInsets.fromLTRB(8, MediaQuery.of(context).padding.top + 8, 16, 0),
                  decoration: BoxDecoration(
                    
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          if (widget.showBackButton)
                            IconButton(
                              icon: Icon(Icons.arrow_back, color: context.appDark),
                              onPressed: () => Navigator.pop(context),
                            ),
                          Text('Mes Bus',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: context.appDark)),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => Navigator.push(
                                context, MaterialPageRoute(builder: (_) => const AddBusScreen())),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: context.appPurple.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(children: [
                                Icon(Icons.add, color: context.appPurple, size: 18),
                                SizedBox(width: 4),
                                Text('Ajouter',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                              ]),
                            ),
                          ),
                        ],
                      ),
                      TabBar(
                        controller: _tabs,
                        labelColor: context.appDark,
                        unselectedLabelColor: context.appSub,
                        indicatorColor: context.appPurple,
                        indicatorWeight: 2.5,
                        tabs: [
                          Tab(text: 'Approuvés (${approved.length})'),
                          Tab(text: 'En attente (${pending.length})'),
                          Tab(text: 'Rejetés (${rejected.length})'),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Tab content ──
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _approvedTab(context, approved),
                      _pendingTab(pending),
                      _rejectedTab(rejected),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ─── Approved ───────────────────────────────
  Widget _approvedTab(BuildContext context, List<Bus> buses) {
    if (buses.isEmpty) {
      return const _Empty(icon: Icons.directions_bus_outlined, message: 'Aucun bus approuvé');
    }
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: buses.length,
      itemBuilder: (context, i) {
        final bus = buses[i];
        return StaggeredListItem(
          index: i,
          child: BusCard(
            bus: bus,
            onEdit: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => AddBusScreen(busToEdit: bus))),
            onDelete: () => _confirmDelete(context, bus),
            onToggleStatus: () async {
              try {
                await _busService.toggleBusStatus(bus.busId, bus.isActive);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(bus.isActive ? 'Bus désactivé' : 'Bus activé'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    margin: EdgeInsets.all(16),
                  ));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(e.toString()),
                    backgroundColor: context.appRed,
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              }
            },
          ),
        );
      },
    );
  }

  // ─── Pending ────────────────────────────────
  Widget _pendingTab(List<Bus> buses) {
    if (buses.isEmpty) {
      return const _Empty(icon: Icons.hourglass_empty, message: 'Aucun bus en attente');
    }
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: buses.length,
      itemBuilder: (_, i) => StaggeredListItem(
        index: i,
        child: _PendingCard(bus: buses[i]),
      ),
    );
  }

  // ─── Rejected ───────────────────────────────
  Widget _rejectedTab(List<Bus> buses) {
    if (buses.isEmpty) {
      return const _Empty(icon: Icons.check_circle_outline, message: 'Aucun bus rejeté');
    }
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: buses.length,
      itemBuilder: (_, i) => StaggeredListItem(
        index: i,
        child: _RejectedCard(bus: buses[i]),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Bus bus) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Supprimer le bus', style: TextStyle(fontWeight: FontWeight.w600)),
        content: Text('Supprimer "${bus.busName}" ?\nCette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Annuler')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _busService.deleteBus(bus.busId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('${bus.busName} supprimé'),
                    backgroundColor: context.appRed,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    margin: EdgeInsets.all(16),
                  ));
                }
              } catch (_) {}
            },
            style: FilledButton.styleFrom(backgroundColor: context.appRed),
            child: Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// PENDING CARD
// ────────────────────────────────────────────────────────────
class _PendingCard extends StatelessWidget {
  final Bus bus;
  const _PendingCard({required this.bus});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appCardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: context.appOrange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(Icons.hourglass_top_rounded, color: context.appOrange, size: 22),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              bus.busName.isNotEmpty ? bus.busName : 'Bus ${bus.busNumber}',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.appDark),
            ),
            SizedBox(height: 2),
            Text('N° ${bus.busNumber}', style: TextStyle(fontSize: 12, color: context.appSub)),
            SizedBox(height: 4),
            Text(
              'En attente de l\'approbation de l\'administrateur',
              style: TextStyle(fontSize: 11, color: context.appSub),
            ),
          ]),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: context.appOrange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('En attente',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.appOrange)),
        ),
      ]),
    );
  }
}

// ────────────────────────────────────────────────────────────
// REJECTED CARD
// ────────────────────────────────────────────────────────────
class _RejectedCard extends StatelessWidget {
  final Bus bus;
  const _RejectedCard({required this.bus});

  @override
  Widget build(BuildContext context) {
    final hasNote = bus.validationNote != null && bus.validationNote!.isNotEmpty;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appCardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: context.appRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.cancel_outlined, color: context.appRed, size: 22),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                bus.busName.isNotEmpty ? bus.busName : 'Bus ${bus.busNumber}',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.appDark),
              ),
              SizedBox(height: 2),
              Text('N° ${bus.busNumber}', style: TextStyle(fontSize: 12, color: context.appSub)),
            ]),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: context.appRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('Rejeté',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.appRed)),
          ),
        ]),

        // Rejection reason
        if (hasNote) ...[
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.appRed.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline, color: context.appRed, size: 15),
              SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Raison du rejet',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.appRed)),
                  SizedBox(height: 2),
                  Text(bus.validationNote!,
                      style: TextStyle(fontSize: 12, color: context.appRed)),
                ]),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}

// ────────────────────────────────────────────────────────────
// EMPTY STATE
// ────────────────────────────────────────────────────────────
class _Empty extends StatelessWidget {
  final IconData icon;
  final String message;
  const _Empty({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 56, color: context.appBorder),
        SizedBox(height: 16),
        Text(message, style: TextStyle(fontSize: 15, color: context.appSub)),
      ]),
    );
  }
}
