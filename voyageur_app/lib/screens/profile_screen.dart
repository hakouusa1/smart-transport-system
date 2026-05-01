import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../locale_notifier.dart';
import '../widgets/bus_loading_indicator.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  Map<String, dynamic>? _userData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
    _slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _loadUser();
  }

  Future<void> _loadUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _userData = doc.data();
          _loading = false;
        });
        _anim.forward();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _logout() {
    final tr = context.tr;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(tr.logoutTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
        content: Text(tr.logoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              FirebaseAuth.instance.signOut();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            style: FilledButton.styleFrom(
              backgroundColor: context.appRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(tr.logoutButton),
          ),
        ],
      ),
    );
  }

  void _showLanguagePicker() {
    final tr = context.tr;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: context.appBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                tr.chooseLanguage,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: context.appText),
              ),
              const SizedBox(height: 16),
              ...AppLanguage.values.map((lang) {
                final isSelected = localeNotifier.value.languageCode == lang.code;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: isSelected
                        ? context.appPrimary.withValues(alpha: 0.08)
                        : context.appCardBg,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: () {
                        localeNotifier.setLocale(Locale(lang.code));
                        Navigator.pop(ctx);
                        setState(() {}); // rebuild with new language
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? context.appPrimary : context.appBorder,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(lang.flag, style: const TextStyle(fontSize: 24)),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    lang.label,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? context.appPrimary : context.appText,
                                    ),
                                  ),
                                  Text(
                                    lang.code.toUpperCase(),
                                    style: TextStyle(fontSize: 11, color: context.appSub),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Icon(Icons.check_circle_rounded, color: context.appPrimary, size: 22),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final user = FirebaseAuth.instance.currentUser;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: context.isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: context.appBg,
        body: _loading
            ? Center(child: BusLoadingIndicator(color: context.appPrimary, strokeWidth: 2.5))
            : FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: CustomScrollView(
                    slivers: [
                      // ── App Bar ──
                      SliverAppBar(
                        pinned: true,
                        backgroundColor: context.appBg,
                        leading: IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.arrow_back_ios_new, color: context.appDark, size: 20),
                        ),
                        title: Text(tr.profileTitle),
                        centerTitle: true,
                      ),

                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            children: [
                              const SizedBox(height: 8),

                              // ═══════════════════════════════════════
                              // AVATAR + NAME
                              // ═══════════════════════════════════════
                              _buildAvatarSection(user),

                              const SizedBox(height: 28),

                              // ═══════════════════════════════════════
                              // ACCOUNT INFO CARD
                              // ═══════════════════════════════════════
                              _buildSectionTitle(tr.accountInfo, Icons.person_outline),
                              const SizedBox(height: 10),
                              _buildInfoCard(),

                              const SizedBox(height: 24),

                              // ═══════════════════════════════════════
                              // SETTINGS
                              // ═══════════════════════════════════════
                              _buildSectionTitle(tr.settings, Icons.settings_outlined),
                              const SizedBox(height: 10),
                              _buildSettingsCard(),

                              const SizedBox(height: 24),

                              // ═══════════════════════════════════════
                              // ABOUT
                              // ═══════════════════════════════════════
                              _buildAboutCard(),

                              const SizedBox(height: 24),

                              // ═══════════════════════════════════════
                              // LOGOUT BUTTON
                              // ═══════════════════════════════════════
                              _buildLogoutButton(),

                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════
  // AVATAR SECTION
  // ═════════════════════════════════════════════════════
  Widget _buildAvatarSection(User? user) {
    final name = _userData?['displayName'] ?? user?.displayName ?? '';
    final initials = name.isNotEmpty
        ? name.trim().split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
        : '?';

    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [context.appPrimary, context.appPurple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: context.appPrimary.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Text(
              initials,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          name.isNotEmpty ? name : 'Voyageur',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: context.appText),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: context.appPrimary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            context.tr.passenger,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.appPrimary),
          ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════
  // SECTION TITLE
  // ═════════════════════════════════════════════════════
  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: context.appSub),
        const SizedBox(width: 6),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: context.appSub,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════
  // ACCOUNT INFO CARD
  // ═════════════════════════════════════════════════════
  Widget _buildInfoCard() {
    final tr = context.tr;
    final user = FirebaseAuth.instance.currentUser;
    final name = _userData?['displayName'] ?? user?.displayName ?? '—';
    final email = _userData?['email'] ?? user?.email ?? '—';
    final createdAt = _userData?['createdAt'] as Timestamp?;
    final date = createdAt?.toDate();

    return Container(
      decoration: BoxDecoration(
        color: context.appCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        children: [
          _InfoRow(icon: Icons.person_outline, label: tr.nameLabel, value: name),
          Divider(height: 1, color: context.appBorder),
          _InfoRow(icon: Icons.email_outlined, label: tr.emailLabel, value: email),
          Divider(height: 1, color: context.appBorder),
          _InfoRow(icon: Icons.badge_outlined, label: tr.roleLabel, value: tr.passenger),
          if (date != null) ...[
            Divider(height: 1, color: context.appBorder),
            _InfoRow(
              icon: Icons.calendar_today_outlined,
              label: tr.memberSince,
              value: tr.formatDate(date),
            ),
          ],
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════
  // SETTINGS CARD
  // ═════════════════════════════════════════════════════
  Widget _buildSettingsCard() {
    final tr = context.tr;
    final currentLang = AppLanguage.fromCode(localeNotifier.value.languageCode);

    return Container(
      decoration: BoxDecoration(
        color: context.appCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        children: [
          // Language selector
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _showLanguagePicker,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: context.appPurple.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.language_rounded, color: context.appPurple, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        tr.language,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.appText),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: context.appCardBg2,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: context.appBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(currentLang.flag, style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Text(
                            currentLang.label,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.appText),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded, color: context.appSub, size: 20),
                  ],
                ),
              ),
            ),
          ),
          Divider(height: 1, color: context.appBorder),

          // Theme toggle
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeNotifier,
            builder: (context, mode, _) {
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => themeNotifier.toggleTheme(),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: context.appOrange.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            mode == ThemeMode.dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                            color: context.appOrange,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            tr.theme,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.appText),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: context.appCardBg2,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: context.appBorder),
                          ),
                          child: Text(
                            mode == ThemeMode.dark ? tr.darkMode : tr.lightMode,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.appText),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right_rounded, color: context.appSub, size: 20),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════
  // ABOUT CARD
  // ═════════════════════════════════════════════════════
  Widget _buildAboutCard() {
    final tr = context.tr;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: context.appGreen.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.info_outline_rounded, color: context.appGreen, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr.about, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.appText)),
                const SizedBox(height: 2),
                Text(tr.aboutDescription, style: TextStyle(fontSize: 12, color: context.appSub)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: context.appCardBg2,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('v1.0.0', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: context.appSub)),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════
  // LOGOUT BUTTON
  // ═════════════════════════════════════════════════════
  Widget _buildLogoutButton() {
    final tr = context.tr;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: _logout,
        icon: Icon(Icons.logout_rounded, color: context.appRed, size: 20),
        label: Text(
          tr.logoutButton,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.appRed),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: context.appRed.withValues(alpha: 0.3), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════
// INFO ROW — used in account info card
// ═════════════════════════════════════════════════════
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: context.appPrimary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: context.appPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: context.appSub)),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.appText),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
