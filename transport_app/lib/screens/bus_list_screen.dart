import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/bus_model.dart';
import '../services/bus_service.dart';
import '../widgets/bus_card.dart';
import 'add_bus_screen.dart';
import '../theme_notifier.dart';
import '../l10n/app_localizations.dart';
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
  List<Bus> _buses = [];
  bool _isLoading = true;
  StreamSubscription<List<Bus>>? _busSub;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    final cached = BusService().latestBuses;
    if (cached != null) {
      _buses = cached;
      _isLoading = false;
    }
    _busSub = _busService.getBuses().listen(
      (buses) {
        if (mounted) setState(() { _buses = buses; _isLoading = false; });
      },
      onError: (_) {
        if (mounted) setState(() => _isLoading = false);
      },
    );
  }

  @override
  void dispose() {
    _busSub?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = _buses;
    final approved = all.where((b) => b.validationStatus == 'approved').toList();
    final pending = all.where((b) => b.validationStatus == 'pending').toList();
    final rejected = all.where((b) => b.validationStatus == 'rejected').toList();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: context.appBg,
        body: _isLoading
            ? Center(child: BusLoadingIndicator(color: context.appPurple, strokeWidth: 2.5))
            : Column(
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

                // ── Plan limit warning ──
                _PlanLimitBanner(busCount: all.length),

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
    final l10n = AppLocalizations.of(context);
    final busDisplayName = bus.busName.isNotEmpty ? bus.busName : 'Bus ${bus.busNumber}';

    showAdaptiveDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DeleteBusDialog(
        busDisplayName: busDisplayName,
        l10n: l10n,
        onConfirm: () async {
          await _busService.deleteBus(bus.busId);
        },
        onSuccess: () {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(l10n.busDeletedFmt(busDisplayName)),
              backgroundColor: context.appRed,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              margin: EdgeInsets.all(16),
            ));
          }
        },
        onError: (error) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(l10n.errorFmt(error)),
              backgroundColor: context.appRed,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              margin: EdgeInsets.all(16),
            ));
          }
        },
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
    return GestureDetector(
      onTap: () => _showChauffeurInfo(context),
      child: Container(
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
      ),
    );
  }

  Future<void> _showChauffeurInfo(BuildContext context) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(bus.driverId).get();
      if (doc.exists) {
        final data = doc.data()!;
        final email = data['email'] ?? 'N/A';
        final mtps = data['mtps'] ?? data['displayName'] ?? 'N/A'; // Assuming mtps or displayName

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Informations du chauffeur', style: TextStyle(fontWeight: FontWeight.w600)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Email: $email'),
                SizedBox(height: 8),
                Text('MTPS: $mtps'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Fermer'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Informations du chauffeur non trouvées'),
          backgroundColor: context.appRed,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur: $e'),
        backgroundColor: context.appRed,
        behavior: SnackBarBehavior.floating,
      ));
    }
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
// PLAN LIMIT WARNING BANNER
// ────────────────────────────────────────────────────────────
class _PlanLimitBanner extends StatelessWidget {
  static const _planLimits = {'starter': 3, 'pro': 10};
  final int busCount;
  const _PlanLimitBanner({required this.busCount});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) return const SizedBox.shrink();
        final data = snap.data!.data() as Map<String, dynamic>;
        final plan = (data['subscription'] as String? ?? 'starter').toLowerCase();
        final limit = _planLimits[plan];
        // null limit = enterprise (unlimited), or no limit known
        if (limit == null || busCount <= limit) return const SizedBox.shrink();

        final planName = plan[0].toUpperCase() + plan.substring(1);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.appOrange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.appOrange.withValues(alpha: 0.35)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.warning_amber_rounded, color: context.appOrange, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    l10n.planLimitExceededFmt(busCount, limit, planName),
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: context.appOrange),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.planLimitExceededAction,
                    style: TextStyle(fontSize: 11, color: context.appSub),
                  ),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }
}

// ────────────────────────────────────────────────────────────
// DELETE BUS CONFIRMATION DIALOG
// ────────────────────────────────────────────────────────────
class _DeleteBusDialog extends StatefulWidget {
  final String busDisplayName;
  final AppLocalizations l10n;
  final Future<void> Function() onConfirm;
  final VoidCallback onSuccess;
  final void Function(String error) onError;

  const _DeleteBusDialog({
    required this.busDisplayName,
    required this.l10n,
    required this.onConfirm,
    required this.onSuccess,
    required this.onError,
  });

  @override
  State<_DeleteBusDialog> createState() => _DeleteBusDialogState();
}

class _DeleteBusDialogState extends State<_DeleteBusDialog> {
  bool _isDeleting = false;

  Future<void> _handleDelete() async {
    if (_isDeleting) return;
    setState(() => _isDeleting = true);

    try {
      await widget.onConfirm();
      if (mounted) Navigator.pop(context);
      widget.onSuccess();
    } catch (e) {
      if (mounted) Navigator.pop(context);
      widget.onError(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;

    return AlertDialog.adaptive(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: context.appCardBg,
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: context.appRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.delete_forever_rounded, color: context.appRed, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.deleteBusConfirmTitle(widget.busDisplayName),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.appDark,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.appRed.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.appRed.withValues(alpha: 0.15)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: context.appRed, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.deleteBusWarning,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.appRed,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actionsPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Row(
          children: [
            // Cancel button
            Expanded(
              child: TextButton(
                onPressed: _isDeleting ? null : () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: context.appBorder),
                  ),
                ),
                child: Text(
                  l10n.cancel,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.appSub,
                  ),
                ),
              ),
            ),
            SizedBox(width: 10),
            // Delete button with loading state
            Expanded(
              child: FilledButton(
                onPressed: _isDeleting ? null : _handleDelete,
                style: FilledButton.styleFrom(
                  backgroundColor: context.appRed,
                  disabledBackgroundColor: context.appRed.withValues(alpha: 0.6),
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isDeleting
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        l10n.deleteLabel,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ],
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
