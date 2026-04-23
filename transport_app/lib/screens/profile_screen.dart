import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../models/subscription_plan.dart';
import '../services/alert_notification_service.dart';
import '../theme_notifier.dart';
import '../widgets/bus_loading_indicator.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  late AnimationController _anim;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Déconnexion',
            style: TextStyle(fontWeight: FontWeight.w600)),
        content: Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text('Annuler')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _authService.signOut();
            },
            style: FilledButton.styleFrom(
              backgroundColor: context.appRed,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Déconnecter'),
          ),
        ],
      ),
    );
  }

  void _editField({
    required String title,
    required String currentValue,
    required String fieldKey,
    TextInputType keyboardType = TextInputType.text,
    int maxLength = 100,
  }) {
    final controller = TextEditingController(text: currentValue);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.appCardBg,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.appBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'Modifier $title',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: context.appDark,
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  maxLength: maxLength,
                  autofocus: true,
                  style: TextStyle(color: context.appDark),
                  decoration: InputDecoration(
                    labelText: title,
                    labelStyle: TextStyle(color: context.appSub),
                    filled: true,
                    fillColor: context.appCardBg2,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          BorderSide(color: context.appPurple, width: 2),
                    ),
                    counterStyle: TextStyle(color: context.appSub),
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: context.appBorder),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text('Annuler',
                            style: TextStyle(color: context.appSub)),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          final newVal = controller.text.trim();
                          if (newVal.isEmpty) return;
                          Navigator.pop(ctx);
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(_authService.uid)
                              .update({fieldKey: newVal});
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('$title mis à jour'),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                backgroundColor: context.appGreen,
                              ),
                            );
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: context.appPurple,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text('Enregistrer'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            context.isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: context.appBg,
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(_authService.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: BusLoadingIndicator());
            }

            final data =
                snapshot.data?.data() as Map<String, dynamic>? ?? {};
            final displayName = data['displayName'] ?? 'Propriétaire';
            final email = data['email'] ?? _authService.currentUser?.email ?? '';
            final phone = data['phone'] ?? '';
            final status = data['subscriptionStatus'] ?? '';
            final createdAt = data['createdAt'] as Timestamp?;
            final trialEnd = data['trialEnd'] as Timestamp?;
            final subscription = data['subscription'] ?? 'starter';
            final expiresAt = data['subscriptionExpiresAt'] as Timestamp?;

            // Compute subscription details
            final planName = SubscriptionPlan.getById(subscription).name;
            String expirationStr = '—';
            String remainingStr = '—';
            if (expiresAt != null) {
              final now = DateTime.now();
              final expDate = expiresAt.toDate();
              expirationStr = _formatDate(expDate);
              final diff = expDate.difference(now);
              if (diff.isNegative) {
                remainingStr = 'Expiré';
              } else if (diff.inDays > 0) {
                remainingStr = '${diff.inDays} jours';
              } else if (diff.inHours > 0) {
                remainingStr = '${diff.inHours} heures';
              } else if (diff.inMinutes > 0) {
                remainingStr = '${diff.inMinutes} minutes';
              } else {
                remainingStr = 'Expire bientôt';
              }
            }

            return FadeTransition(
              opacity: _fade,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // ════════════════════════════════════════
                    // HEADER
                    // ════════════════════════════════════════
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                          20, MediaQuery.of(context).padding.top + 16, 20, 0),
                      child: Row(
                        children: [
                          Text(
                            'Mon Profil',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: context.appDark,
                            ),
                          ),
                           const Spacer(),
                        ],
                      ),
                    ),

                    SizedBox(height: 28),

                    // ════════════════════════════════════════
                    // AVATAR + NAME
                    // ════════════════════════════════════════
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            context.appPurple,
                            context.appPrimary,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: context.appPurple.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _initials(displayName),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 14),
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: context.appDark,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.appSub,
                      ),
                    ),
                    SizedBox(height: 8),
                    // Status badge
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: _statusColor(status, context)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _statusLabel(status),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _statusColor(status, context),
                        ),
                      ),
                    ),

                    SizedBox(height: 28),

                    // ════════════════════════════════════════
                    // INFO SECTION
                    // ════════════════════════════════════════
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: context.appCardBg,
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: context.appBorder, width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding:
                                  EdgeInsets.fromLTRB(18, 18, 18, 0),
                              child: Text(
                                'Informations personnelles',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: context.appDark,
                                ),
                              ),
                            ),
                            SizedBox(height: 4),
                            _ProfileTile(
                              icon: Icons.person_outline,
                              label: 'Nom complet',
                              value: displayName,
                              onEdit: () => _editField(
                                title: 'Nom complet',
                                currentValue: displayName,
                                fieldKey: 'displayName',
                              ),
                            ),
                            _Divider(),
                            _ProfileTile(
                              icon: Icons.email_outlined,
                              label: 'Email',
                              value: email,
                              // Email is tied to Firebase Auth — not editable here
                              onEdit: null,
                            ),
                            _Divider(),
                            _ProfileTile(
                              icon: Icons.phone_outlined,
                              label: 'Téléphone',
                              value: phone.isNotEmpty
                                  ? phone
                                  : 'Non renseigné',
                              onEdit: () => _editField(
                                title: 'Téléphone',
                                currentValue: phone,
                                fieldKey: 'phone',
                                keyboardType: TextInputType.phone,
                                maxLength: 15,
                              ),
                            ),
                            _Divider(),
                             _ProfileTile(
                               icon: Icons.calendar_today_outlined,
                               label: 'Membre depuis',
                               value: createdAt != null
                                   ? _formatDate(createdAt.toDate())
                                   : '—',
                               onEdit: null,
                             ),
                             _Divider(),
                             _ProfileTile(
                               icon: Icons.workspace_premium_outlined,
                               label: 'Plan actuel',
                               value: planName,
                               onEdit: null,
                             ),
                             _Divider(),
                             _ProfileTile(
                               icon: Icons.event_outlined,
                               label: 'Expiration',
                               value: expirationStr,
                               onEdit: null,
                             ),
                             _Divider(),
                             _ProfileTile(
                               icon: Icons.timer_outlined,
                               label: 'Temps restant',
                               value: remainingStr,
                               onEdit: null,
                               valueColor: remainingStr == 'Expiré' ? context.appRed : null,
                             ),
                             if (trialEnd != null &&
                                 trialEnd
                                     .toDate()
                                     .isAfter(DateTime.now())) ...[
                               _Divider(),
                               _ProfileTile(
                                 icon: Icons.timer_outlined,
                                 label: 'Fin de l\'essai',
                                 value: _formatDate(trialEnd.toDate()),
                                 onEdit: null,
                                 valueColor: context.appOrange,
                               ),
                             ],
                            SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 20),

                    // ════════════════════════════════════════
                    // ACTIONS SECTION
                    // ════════════════════════════════════════
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: context.appCardBg,
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: context.appBorder, width: 1),
                        ),
                        child: Column(
                          children: [
                            // Change password
                            _ActionTile(
                              icon: Icons.lock_outline,
                              label: 'Changer le mot de passe',
                              iconColor: context.appPurple,
                              onTap: () => _resetPassword(email),
                            ),
                            _Divider(),
                            // Test alerts
                            _ActionTile(
                              icon: Icons.notifications_active_outlined,
                              label: 'Tester les notifications d\'alertes',
                              iconColor: context.appOrange,
                              onTap: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                final orange = context.appOrange;
                                await AlertNotificationService.testAll();
                                if (!mounted) return;
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: const Text('Notifications envoyées'),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                    backgroundColor: orange,
                                  ),
                                );
                              },
                            ),
                            _Divider(),
                            // Logout
                            _ActionTile(
                              icon: Icons.logout_rounded,
                              label: 'Se déconnecter',
                              iconColor: context.appRed,
                              labelColor: context.appRed,
                              onTap: () => _confirmLogout(context),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 40),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _resetPassword(String email) async {
    if (email.isEmpty) return;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Email de réinitialisation envoyé à $email'),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: context.appGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: context.appRed,
          ),
        );
      }
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String _formatDate(DateTime dt) {
    const months = [
      '', 'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin',
      'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc',
    ];
    return '${dt.day} ${months[dt.month]} ${dt.year}';
  }

  Color _statusColor(String status, BuildContext context) {
    switch (status) {
      case 'active':
        return context.appGreen;
      case 'pending':
        return context.appOrange;
      case 'inactive':
      case 'expired':
        return context.appRed;
      default:
        return context.appSub;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'active':
        return 'Abonnement actif';
      case 'pending':
        return 'En attente';
      case 'inactive':
        return 'Inactif';
      case 'expired':
        return 'Expiré';
      default:
        return 'Essai gratuit';
    }
  }
}

// ════════════════════════════════════════
// PROFILE TILE (info row with edit)
// ════════════════════════════════════════
class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onEdit;
  final Color? valueColor;

  const _ProfileTile({
    required this.icon,
    required this.label,
    required this.value,
    this.onEdit,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: context.appPurple.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: context.appPurple, size: 18),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.appSub,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: valueColor ?? context.appDark,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (onEdit != null)
              Icon(Icons.edit_outlined, color: context.appSub, size: 16),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════
// ACTION TILE (logout, password, etc.)
// ════════════════════════════════════════
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color? labelColor;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.iconColor,
    this.labelColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: labelColor ?? context.appDark,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: context.appSub, size: 20),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════
// THIN DIVIDER
// ════════════════════════════════════════
class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 18),
      child: Divider(height: 1, color: context.appBorder.withValues(alpha: 0.5)),
    );
  }
}
