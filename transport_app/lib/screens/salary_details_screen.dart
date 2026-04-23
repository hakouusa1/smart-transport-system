import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/bus_model.dart';
import '../theme_notifier.dart';
import '../widgets/bus_loading_indicator.dart';



class SalaryDetailsScreen extends StatelessWidget {
  final Bus bus;
  final int? daysUntilSalary;

  const SalaryDetailsScreen({
    super.key,
    required this.bus,
    required this.daysUntilSalary,
  });

  Future<void> _markSalaryAsPaid(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirmer le paiement'),
        content: Text('Voulez-vous marquer le salaire comme payé pour ce mois ?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: TextStyle(color: context.appSub, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.appPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('buses').doc(bus.busId).update({
          'lastSalaryDate': FieldValue.serverTimestamp(),
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Salaire marqué comme payé avec succès.'), backgroundColor: context.appGreen),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: context.appRed),
          );
        }
      }
    }
  }

  Future<Map<String, String>> _fetchEmployeeNames() async {
    String driverName = 'Non assigné';
    String recipientName = 'Non assigné';

    if (bus.driverId.isNotEmpty) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(bus.driverId).get();
        if (doc.exists) {
          driverName = doc.data()?['name'] ?? 'Chauffeur Inconnu';
        }
      } catch (_) {}
    }

    if (bus.recipientSalary != null && bus.recipientSalary! > 0) {
      recipientName = 'Employé (Salaire: ${bus.recipientSalary} FCFA)';
    }

    return {
      'driver': driverName,
      'recipient': recipientName,
    };
  }

  @override
  Widget build(BuildContext context) {
    Color statusColor = context.appGreen;
    String statusTitle = 'Délai normal';
    String statusSubtitle = '';

    if (daysUntilSalary == null) {
      statusColor = context.appSub;
      statusTitle = 'Date inconnue';
    } else if (daysUntilSalary == 0) {
      statusColor = context.appRed;
      statusTitle = 'Paiement aujourd\'hui !';
      statusSubtitle = 'Le salaire doit être versé aujourd\'hui.';
    } else if (daysUntilSalary! <= 3) {
      statusColor = context.appRed;
      statusTitle = 'Paiement imminent';
      statusSubtitle = 'Prévoyez le versement du salaire prochainement.';
    } else if (daysUntilSalary! <= 10) {
      statusColor = context.appOrange;
      statusTitle = 'Bientôt à terme';
      statusSubtitle = 'Le 1er du mois approche.';
    } else {
      statusSubtitle = 'Vous êtes dans les temps.';
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: context.appBg,
        body: Column(
          children: [
            // ── Header ──
            Container(
              padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 24),
              decoration: BoxDecoration(
                
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: context.appPurple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(Icons.arrow_back, color: context.appDark),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Détails des Salaires',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: EdgeInsets.all(20),
                children: [
                  // Title card
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(Icons.payments_outlined, color: statusColor, size: 28),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    bus.busName.isNotEmpty ? bus.busName : 'Bus ${bus.busNumber}',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.appDark),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    statusTitle,
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: statusColor),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (statusSubtitle.isNotEmpty) ...[
                            SizedBox(height: 12),
                            Text(
                              statusSubtitle,
                              style: TextStyle(fontSize: 13, color: context.appSub),
                            ),
                        ],
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Divider(height: 1, color: context.appBorder),
                        ),
                        _buildDetailRow(
                          context,
                          'Date de paiement',
                          daysUntilSalary != null ? DateFormat('dd/MM/yyyy').format(DateTime.now().add(Duration(days: daysUntilSalary!))) : 'Inconnue'
                        ),
                        SizedBox(height: 12),
                        _buildDetailRow(
                          context,
                          'Jours restants',
                          daysUntilSalary != null ? '${daysUntilSalary!} jour${daysUntilSalary! > 1 ? 's' : ''}' : 'Inconnu',
                          valueColor: statusColor,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24),

                  Text('Équipe assignée', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.appDark)),
                  SizedBox(height: 12),

                  // Employees List
                  FutureBuilder<Map<String, String>>(
                    future: _fetchEmployeeNames(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: BusLoadingIndicator(color: context.appPurple),
                          ),
                        );
                      }

                      final names = snapshot.data ?? {'driver': 'Erreur', 'recipient': 'Erreur'};

                      return Column(
                        children: [
                          if (bus.driverId.isNotEmpty)
                            _buildEmployeeCard(context,
                              role: 'Chauffeur',
                              name: names['driver']!,
                              icon: Icons.person_outline,
                            ),
                          if (bus.driverId.isNotEmpty && (bus.recipientSalary != null && bus.recipientSalary! > 0))
                            SizedBox(height: 12),
                          if (bus.recipientSalary != null && bus.recipientSalary! > 0)
                            _buildEmployeeCard(context,
                              role: 'Receveur',
                              name: names['recipient']!,
                              icon: Icons.person_2_outlined,
                            ),
                          if (bus.driverId.isEmpty && (bus.recipientSalary == null || bus.recipientSalary! <= 0))
                            Container(
                              padding: EdgeInsets.all(20),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                
                              ),
                              child: Text('Aucun employé assigné à ce bus', style: TextStyle(color: context.appSub)),
                            ),
                          SizedBox(height: 32),
                          if (bus.driverId.isNotEmpty || (bus.recipientSalary != null && bus.recipientSalary! > 0))
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: context.appPurple,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  elevation: 0,
                                ),
                                onPressed: () => _markSalaryAsPaid(context),
                                icon: Icon(Icons.check_circle_outline),
                                label: Text('Marquer comme payé', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                              ),
                            ),
                          if (bus.lastSalaryDate != null) ...[
                            SizedBox(height: 16),
                            Center(
                              child: Text(
                                'Dernier paiement : ${DateFormat('dd/MM/yyyy à HH:mm').format(bus.lastSalaryDate!)}',
                                style: TextStyle(color: context.appSub, fontSize: 13),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: context.appSub)),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: valueColor ?? context.appDark,
          ),
        ),
      ],
    );
  }

  Widget _buildEmployeeCard(BuildContext context, {required String role, required String name, required IconData icon}) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.appPurple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: context.appPurple, size: 24),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(role, style: TextStyle(fontSize: 13, color: context.appSub, fontWeight: FontWeight.w600)),
                SizedBox(height: 4),
                Text(name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.appDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
