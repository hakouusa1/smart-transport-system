import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../models/subscription_plan.dart';
import '../services/alert_notification_service.dart';
import '../theme_notifier.dart';
import '../locale_notifier.dart';
import '../l10n/app_localizations.dart';
import '../app_settings_notifier.dart';
import '../widgets/bus_loading_indicator.dart';
import './subscription_history_screen.dart';
import './change_plan_screen.dart';

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
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.logoutTitle,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        content: Text(l10n.logoutConfirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel)),
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
            child: Text(l10n.logoutAction),
          ),
        ],
      ),
    );
  }

  void _editField({
    required BuildContext context,
    required String title,
    required String currentValue,
    required String fieldKey,
    TextInputType keyboardType = TextInputType.text,
    int maxLength = 100,
  }) {
    final l10n = AppLocalizations.of(context);
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
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.appCardBg,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const SizedBox(height: 20),
                Text(
                  l10n.editFieldTitle(title),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: context.appDark,
                  ),
                ),
                const SizedBox(height: 16),
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
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: context.appBorder),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(l10n.cancel,
                            style: TextStyle(color: context.appSub)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          final newVal = controller.text.trim();
                          if (newVal.isEmpty) return;
                          Navigator.pop(ctx);
                          final messenger = ScaffoldMessenger.of(context);
                          final green = context.appGreen;
                          final msg = l10n.fieldUpdatedFmt(title);
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(_authService.uid)
                              .update({fieldKey: newVal});
                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(msg),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                backgroundColor: green,
                              ),
                            );
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: context.appPurple,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(l10n.save),
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

  void _showLanguagePicker(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: context.appCardBg,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const SizedBox(height: 20),
              Text(
                l10n.languageLabel,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: context.appDark,
                ),
              ),
              const SizedBox(height: 16),
              _LanguageOption(
                flag: '🇫🇷',
                name: l10n.langFrench,
                code: 'fr',
                isSelected: localeNotifier.value.languageCode == 'fr',
              ),
              _Divider(),
              _LanguageOption(
                flag: '🇬🇧',
                name: l10n.langEnglish,
                code: 'en',
                isSelected: localeNotifier.value.languageCode == 'en',
              ),
              _Divider(),
              _LanguageOption(
                flag: '🇸🇦',
                name: l10n.langArabic,
                code: 'ar',
                isSelected: localeNotifier.value.languageCode == 'ar',
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showSettingEditor({
    required BuildContext context,
    required String label,
    required String currentValue,
    required bool isInt,
    required Future<void> Function(String) onSave,
  }) {
    final l10n = AppLocalizations.of(context);
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
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.appCardBg,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const SizedBox(height: 20),
                Text(
                  '${l10n.editSettingTitle} — $label',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: context.appDark,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  keyboardType: isInt
                      ? TextInputType.number
                      : const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                  style: TextStyle(color: context.appDark),
                  decoration: InputDecoration(
                    labelText: label,
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
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: context.appBorder),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(l10n.cancel,
                            style: TextStyle(color: context.appSub)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          final raw = controller.text.trim();
                          final valid = isInt
                              ? (int.tryParse(raw) != null &&
                                  int.parse(raw) > 0)
                              : (double.tryParse(raw) != null &&
                                  double.parse(raw) > 0);
                          if (!valid) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l10n.invalidNumber),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                backgroundColor: context.appRed,
                              ),
                            );
                            return;
                          }
                          Navigator.pop(ctx);
                          final messenger = ScaffoldMessenger.of(context);
                          final green = context.appGreen;
                          final msg = l10n.settingsSaved;
                          await onSave(raw);
                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(msg),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                backgroundColor: green,
                              ),
                            );
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: context.appPurple,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(l10n.save),
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
    final l10n = AppLocalizations.of(context);

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
              return const Center(child: BusLoadingIndicator());
            }

            final data =
                snapshot.data?.data() as Map<String, dynamic>? ?? {};
            final displayName = data['displayName'] ?? l10n.defaultOwnerName;
            final email = data['email'] ?? _authService.currentUser?.email ?? '';
            final phone = data['phone'] ?? '';
            final status = data['subscriptionStatus'] ?? '';
            final createdAt = data['createdAt'] as Timestamp?;
            final trialEnd = data['trialEnd'] as Timestamp?;
            final subscription = data['subscription'] ?? 'starter';
            final expiresAt = data['subscriptionExpiresAt'] as Timestamp?;

            final planName = SubscriptionPlan.getById(subscription).name;
            String expirationStr = '—';
            String remainingStr = '—';
            bool isRemainingExpired = false;
            if (expiresAt != null) {
              final now = DateTime.now();
              final expDate = expiresAt.toDate();
              expirationStr = l10n.formatDate(expDate);
              final diff = expDate.difference(now);
              if (diff.isNegative) {
                remainingStr = l10n.expiredLabel;
                isRemainingExpired = true;
              } else if (diff.inDays > 0) {
                remainingStr = l10n.daysFmt(diff.inDays);
              } else if (diff.inHours > 0) {
                remainingStr = l10n.hoursFmt(diff.inHours);
              } else if (diff.inMinutes > 0) {
                remainingStr = l10n.minutesFmt(diff.inMinutes);
              } else {
                remainingStr = l10n.expiresSoon;
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
                            l10n.myProfile,
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

                    const SizedBox(height: 28),

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
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _initials(displayName),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: context.appDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.appSub,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Status badge
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: _statusColor(status, context)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        l10n.statusLabel(status),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _statusColor(status, context),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ════════════════════════════════════════
                    // INFO SECTION
                    // ════════════════════════════════════════
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
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
                                  const EdgeInsets.fromLTRB(18, 18, 18, 0),
                              child: Text(
                                l10n.personalInfo,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: context.appDark,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            _ProfileTile(
                              icon: Icons.person_outline,
                              label: l10n.fullName,
                              value: displayName,
                              onEdit: () => _editField(
                                context: context,
                                title: l10n.fullName,
                                currentValue: displayName,
                                fieldKey: 'displayName',
                              ),
                            ),
                            _Divider(),
                            _ProfileTile(
                              icon: Icons.email_outlined,
                              label: l10n.emailLabel,
                              value: email,
                              onEdit: null,
                            ),
                            _Divider(),
                            _ProfileTile(
                              icon: Icons.phone_outlined,
                              label: l10n.phone,
                              value: phone.isNotEmpty ? phone : l10n.notProvided,
                              onEdit: () => _editField(
                                context: context,
                                title: l10n.phone,
                                currentValue: phone,
                                fieldKey: 'phone',
                                keyboardType: TextInputType.phone,
                                maxLength: 15,
                              ),
                            ),
                            _Divider(),
                            _ProfileTile(
                              icon: Icons.calendar_today_outlined,
                              label: l10n.memberSince,
                              value: createdAt != null
                                  ? l10n.formatDate(createdAt.toDate())
                                  : '—',
                              onEdit: null,
                            ),
                            _Divider(),
                            _ProfileTile(
                              icon: Icons.workspace_premium_outlined,
                              label: l10n.currentPlan,
                              value: planName,
                              onEdit: null,
                            ),
                            _Divider(),
                            _ProfileTile(
                              icon: Icons.event_outlined,
                              label: l10n.expiration,
                              value: expirationStr,
                              onEdit: null,
                            ),
                            _Divider(),
                            _ProfileTile(
                              icon: Icons.timer_outlined,
                              label: l10n.timeRemaining,
                              value: remainingStr,
                              onEdit: null,
                              valueColor: isRemainingExpired ? context.appRed : null,
                            ),
                            if (trialEnd != null &&
                                trialEnd.toDate().isAfter(DateTime.now())) ...[
                              _Divider(),
                              _ProfileTile(
                                icon: Icons.timer_outlined,
                                label: l10n.trialEndLabel,
                                value: l10n.formatDate(trialEnd.toDate()),
                                onEdit: null,
                                valueColor: context.appOrange,
                              ),
                            ],
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ════════════════════════════════════════
                    // SETTINGS SECTION (Language)
                    // ════════════════════════════════════════
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
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
                                  const EdgeInsets.fromLTRB(18, 18, 18, 0),
                              child: Text(
                                l10n.settingsSection,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: context.appDark,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            ValueListenableBuilder<Locale>(
                              valueListenable: localeNotifier,
                              builder: (context, locale, _) {
                                return _ActionTile(
                                  icon: Icons.language_outlined,
                                  label:
                                      '${l10n.languageLabel}: ${l10n.currentLanguageName(locale.languageCode)}',
                                  iconColor: context.appPrimary,
                                  onTap: () => _showLanguagePicker(context),
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ════════════════════════════════════════
                    // APP SETTINGS SECTION (Fleet Economics)
                    // ════════════════════════════════════════
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: context.appCardBg,
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: context.appBorder, width: 1),
                        ),
                        child: ValueListenableBuilder<AppSettings>(
                          valueListenable: appSettingsNotifier,
                          builder: (context, settings, _) {
                            final l10n = AppLocalizations.of(context);
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(18, 18, 18, 0),
                                  child: Text(
                                    l10n.appSettingsTitle,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: context.appDark,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                _ProfileTile(
                                  icon: Icons.local_gas_station_outlined,
                                  label: l10n.fuelPriceLabel,
                                  value:
                                      '${settings.fuelPricePerLiter.toStringAsFixed(0)} DA/L',
                                  onEdit: () => _showSettingEditor(
                                    context: context,
                                    label: l10n.fuelPriceLabel,
                                    currentValue: settings.fuelPricePerLiter
                                        .toStringAsFixed(0),
                                    isInt: false,
                                    onSave: (v) => appSettingsNotifier
                                        .setFuelPrice(double.parse(v)),
                                  ),
                                ),
                                _Divider(),
                                _ProfileTile(
                                  icon: Icons.oil_barrel_outlined,
                                  label: l10n.vidangeIntervalLabel,
                                  value: '${settings.vidangeIntervalKm} km',
                                  onEdit: () => _showSettingEditor(
                                    context: context,
                                    label: l10n.vidangeIntervalLabel,
                                    currentValue:
                                        '${settings.vidangeIntervalKm}',
                                    isInt: true,
                                    onSave: (v) => appSettingsNotifier
                                        .setVidangeInterval(int.parse(v)),
                                  ),
                                ),
                                _Divider(),
                                _ProfileTile(
                                  icon: Icons.speed_outlined,
                                  label: l10n.fuelConsumptionLabel,
                                  value:
                                      '${settings.fuelConsumptionL100.toStringAsFixed(1)} L/100km',
                                  onEdit: () => _showSettingEditor(
                                    context: context,
                                    label: l10n.fuelConsumptionLabel,
                                    currentValue: settings.fuelConsumptionL100
                                        .toStringAsFixed(1),
                                    isInt: false,
                                    onSave: (v) => appSettingsNotifier
                                        .setFuelConsumption(double.parse(v)),
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ════════════════════════════════════════
                    // ACTIONS SECTION
                    // ════════════════════════════════════════
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: context.appCardBg,
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: context.appBorder, width: 1),
                        ),
                        child: Column(
                          children: [
                            _ActionTile(
                              icon: Icons.lock_outline,
                              label: l10n.changePassword,
                              iconColor: context.appPurple,
                              onTap: () => _resetPassword(context, email),
                            ),
                            _Divider(),
                            _ActionTile(
                              icon: Icons.history_rounded,
                              label: l10n.subscriptionHistory,
                              iconColor: context.appPrimary,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const SubscriptionHistoryScreen()),
                                );
                              },
                            ),
                            if (status == 'active') ...[
                              _Divider(),
                              _ActionTile(
                                icon: Icons.swap_vert_circle_outlined,
                                label: l10n.changePlan,
                                iconColor: context.appGreen,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChangePlanScreen(
                                          currentPlanId: subscription),
                                    ),
                                  );
                                },
                              ),
                            ],
                            _Divider(),
                            _ActionTile(
                              icon: Icons.notifications_active_outlined,
                              label: l10n.testAlertNotifs,
                              iconColor: context.appOrange,
                              onTap: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                final orange = context.appOrange;
                                final sent = l10n.notificationsSent;
                                await AlertNotificationService.testAll();
                                if (!mounted) return;
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(sent),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                    backgroundColor: orange,
                                  ),
                                );
                              },
                            ),
                            _Divider(),
                            _ActionTile(
                              icon: Icons.logout_rounded,
                              label: l10n.signOut,
                              iconColor: context.appRed,
                              labelColor: context.appRed,
                              onTap: () => _confirmLogout(context),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _resetPassword(BuildContext context, String email) async {
    final l10n = AppLocalizations.of(context);
    if (email.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final green = context.appGreen;
    final red = context.appRed;
    final successMsg = l10n.passwordResetSentFmt(email);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(successMsg),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.errorFmt(e.toString())),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: red,
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
}

// ════════════════════════════════════════
// LANGUAGE OPTION TILE (inside picker sheet)
// ════════════════════════════════════════
class _LanguageOption extends StatelessWidget {
  final String flag;
  final String name;
  final String code;
  final bool isSelected;

  const _LanguageOption({
    required this.flag,
    required this.name,
    required this.code,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        localeNotifier.setLocale(Locale(code));
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? context.appPrimary : context.appDark,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: context.appPrimary, size: 20),
          ],
        ),
      ),
    );
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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
            const SizedBox(width: 14),
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
                  const SizedBox(height: 2),
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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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
            const SizedBox(width: 14),
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
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Divider(height: 1, color: context.appBorder.withValues(alpha: 0.5)),
    );
  }
}
