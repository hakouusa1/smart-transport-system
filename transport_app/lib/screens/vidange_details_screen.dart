import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bus_model.dart';
import 'package:intl/intl.dart';
import '../theme_notifier.dart';
import '../widgets/bus_loading_indicator.dart';



class VidangeDetailsScreen extends StatefulWidget {
  final Bus bus;
  final int? kmRemaining;
  final int intervalKm;

  const VidangeDetailsScreen({
    super.key,
    required this.bus,
    required this.kmRemaining,
    required this.intervalKm,
  });

  @override
  State<VidangeDetailsScreen> createState() => _VidangeDetailsScreenState();
}

class _VidangeDetailsScreenState extends State<VidangeDetailsScreen> {
  bool _isLoading = false;

  Future<void> _resetVidange() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('buses').doc(widget.bus.busId).update({
        'lastVidangeDate': Timestamp.now(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vidange enregistrée avec succès'),
            backgroundColor: context.appGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            margin: EdgeInsets.all(16),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: context.appRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            margin: EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bus = widget.bus;
    final km = widget.kmRemaining;
    
    // Status text and color logic based on km
    Color statusColor = context.appGreen;
    String statusTitle = 'Vidange normale';
    
    if (km == null) {
      statusColor = context.appSub;
      statusTitle = 'Données manquantes';
    } else if (km < 0) {
      statusColor = context.appRed;
      statusTitle = 'Vidange dépassée !';
    } else if (km <= 1000) {
      statusColor = context.appOrange;
      statusTitle = 'Vidange imminente';
    }

    final lastDate = bus.lastVidangeDate != null 
        ? DateFormat('dd/MM/yyyy').format(bus.lastVidangeDate!)
        : 'Inconnue';

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
                      'Détails Vidange',
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
                              child: Icon(Icons.oil_barrel_outlined, color: statusColor, size: 28),
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
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Divider(height: 1, color: context.appBorder),
                        ),
                        _buildDetailRow('Dernière vidange', lastDate),
                        SizedBox(height: 12),
                        _buildDetailRow(
                          'Distance restante', 
                          km != null ? '${km < 0 ? km : km} km' : 'Inconnue',
                          valueColor: statusColor,
                        ),
                        SizedBox(height: 12),
                        _buildDetailRow('Intervalle', '${widget.intervalKm} km'),
                      ],
                    ),
                  ),

                  SizedBox(height: 32),

                  // Reset Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : () => _confirmResetVidange(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.appPurple,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: _isLoading
                          ? SizedBox(width: 24, height: 24, child: BusLoadingIndicator(color: Colors.white, strokeWidth: 2))
                          : Icon(Icons.check_circle_outline),
                      label: Text(
                        _isLoading ? 'Enregistrement...' : 'Faire la vidange',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'En cliquant sur ce bouton, vous confirmez que l\'huile a été changée. Le compteur sera réinitialisé.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: context.appSub),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
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

  void _confirmResetVidange(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Confirmer la vidange', style: TextStyle(fontWeight: FontWeight.w600)),
        content: Text('Voulez-vous vraiment marquer la vidange comme effectuée ? Le compteur kilométrique sera réinitialisé à la distance maximale.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _resetVidange();
            },
            style: FilledButton.styleFrom(backgroundColor: context.appPurple),
            child: Text('Confirmer'),
          ),
        ],
      ),
    );
  }
}
