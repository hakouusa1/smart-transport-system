import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme.dart';
import '../services/admin_notification_service.dart';
import '../widgets/notification_badge_widget.dart';
import 'dashboard_page.dart';
import 'new_owners_page.dart';
import 'new_buses_page.dart';
import 'users_page.dart';
import 'lines_page.dart';
import 'buses_page.dart';
import 'bookings_page.dart';
import 'incidents_page.dart';
import 'stats_page.dart';
import 'offers_page.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});
  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _page = 0;
  final Set<int> _visited = {0};
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  static final _pageWidgets = <Widget>[
    const DashboardPage(),
    const NewOwnersPage(),
    const NewBusesPage(),
    const UsersPage(),
    const OffersPage(),
    const LinesPage(),
    const BusesPage(),
    const BookingsPage(),
    const StatsPage(),
    const IncidentsPage(),
  ];

  static final _pages = [
    _PageDef(Icons.dashboard_rounded, 'Dashboard', null),
    _PageDef(Icons.star_rounded, 'New Subscriptions', AdminNotificationService.getPendingSubscriptionsCount()),
    _PageDef(Icons.new_releases_rounded, 'New Buses', AdminNotificationService.getPendingBusesCount()),
    _PageDef(Icons.people_rounded, 'Utilisateurs', null),
    _PageDef(Icons.workspace_premium_rounded, 'Offres', null),
    _PageDef(Icons.route_rounded, 'Lignes', null),
    _PageDef(Icons.directions_bus_rounded, 'Bus', null),
    _PageDef(Icons.bookmark_rounded, 'Réservations', null),
    _PageDef(Icons.bar_chart_rounded, 'Statistiques', null),
    _PageDef(Icons.warning_rounded, 'Incidents', null),
  ];

  void _selectPage(int i) {
    setState(() { _visited.add(i); _page = i; });
    // Close drawer if open (mobile)
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isMobile = w <= 600;
    final expanded = w > 900;
    final collapsed = w > 600 && w <= 900;

    return Scaffold(
      key: _scaffoldKey,
      // ── DRAWER for mobile ──
      drawer: isMobile ? Drawer(
        backgroundColor: AppColors.deepNavy,
        child: SafeArea(
          child: Column(children: [
            const SizedBox(height: 16),
            // Logo
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: AppColors.blue, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text('Admin Panel', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5)),
              ]),
            ),
            const SizedBox(height: 12),
            Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
            const SizedBox(height: 8),

            // Nav items
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: List.generate(_pages.length, (i) {
                  final p = _pages[i];
                  if (p.countStream != null) {
                    return NavItemWithBadge(
                      icon: p.icon, label: p.label,
                      countStream: p.countStream!,
                      selected: _page == i, expanded: true,
                      onTap: () => _selectPage(i),
                    );
                  }
                  return _SidebarItem(
                    icon: p.icon, label: p.label,
                    selected: _page == i, expanded: true,
                    onTap: () => _selectPage(i),
                  );
                }),
              ),
            ),

            Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
            // User info + logout
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                CircleAvatar(radius: 16, backgroundColor: AppColors.blue.withValues(alpha: 0.3),
                  child: const Icon(Icons.person, size: 16, color: AppColors.ice)),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  FirebaseAuth.instance.currentUser?.email?.split('@').first ?? 'Admin',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                  overflow: TextOverflow.ellipsis)),
                IconButton(
                  icon: Icon(Icons.logout, color: Colors.white.withValues(alpha: 0.5), size: 18),
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  tooltip: 'Déconnexion',
                ),
              ]),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ) : null,

      // ── APP BAR for mobile ──
      appBar: isMobile ? AppBar(
        backgroundColor: AppColors.deepNavy,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(color: AppColors.blue, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Text(_pages[_page].label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white.withValues(alpha: 0.7), size: 20),
            onPressed: () => FirebaseAuth.instance.signOut(),
            tooltip: 'Déconnexion',
          ),
        ],
      ) : null,

      body: Row(children: [
        // ── SIDEBAR (desktop/tablet only) ──
        if (!isMobile)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: expanded ? 250 : collapsed ? 72 : 0,
            decoration: const BoxDecoration(
              color: AppColors.deepNavy,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(2, 0))],
            ),
            child: Column(children: [
              const SizedBox(height: 28),
              // Logo
              if (expanded)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: AppColors.blue, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text('Admin Panel', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5)),
                  ]),
                )
              else if (collapsed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: AppColors.blue, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 20),
                  ),
                ),

              const SizedBox(height: 20),
              Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
              const SizedBox(height: 8),

              // Nav items
              ...List.generate(_pages.length, (i) {
                final p = _pages[i];
                if (p.countStream != null) {
                  return NavItemWithBadge(
                    icon: p.icon, label: p.label,
                    countStream: p.countStream!,
                    selected: _page == i, expanded: expanded,
                    onTap: () => setState(() { _visited.add(i); _page = i; }),
                  );
                }
                return _SidebarItem(
                  icon: p.icon, label: p.label,
                  selected: _page == i, expanded: expanded,
                  onTap: () => setState(() { _visited.add(i); _page = i; }),
                );
              }),

              const Spacer(),
              Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),

              // User info + logout
              Padding(
                padding: const EdgeInsets.all(12),
                child: expanded
                    ? Row(children: [
                        CircleAvatar(radius: 16, backgroundColor: AppColors.blue.withValues(alpha: 0.3),
                          child: const Icon(Icons.person, size: 16, color: AppColors.ice)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(
                          FirebaseAuth.instance.currentUser?.email?.split('@').first ?? 'Admin',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                          overflow: TextOverflow.ellipsis)),
                        IconButton(
                          icon: Icon(Icons.logout, color: Colors.white.withValues(alpha: 0.5), size: 18),
                          onPressed: () => FirebaseAuth.instance.signOut(),
                          tooltip: 'Déconnexion',
                        ),
                      ])
                    : IconButton(
                        icon: Icon(Icons.logout, color: Colors.white.withValues(alpha: 0.5), size: 18),
                        onPressed: () => FirebaseAuth.instance.signOut(),
                      ),
              ),
              const SizedBox(height: 8),
            ]),
          ),

        // ── CONTENT ──
        Expanded(
          child: IndexedStack(
            index: _page,
            children: [
              for (var i = 0; i < _pages.length; i++)
                if (_visited.contains(i)) _pageWidgets[i] else const SizedBox.shrink(),
            ],
          ),
        ),
      ]),
    );
  }
}

class _PageDef {
  final IconData icon;
  final String label;
  final Stream<int>? countStream;
  const _PageDef(this.icon, this.label, this.countStream);
}

class _SidebarItem extends StatefulWidget {
  final IconData icon; final String label; final bool selected, expanded; final VoidCallback onTap;
  const _SidebarItem({required this.icon, required this.label, required this.selected, required this.expanded, required this.onTap});
  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected;
    final fg = active ? Colors.white : Colors.white.withValues(alpha: _hover ? 0.8 : 0.5);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: EdgeInsets.symmetric(horizontal: widget.expanded ? 14 : 0, vertical: 11),
          decoration: BoxDecoration(
            color: active ? AppColors.blue.withValues(alpha: 0.2) : (_hover ? Colors.white.withValues(alpha: 0.04) : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: widget.expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: fg, size: 20),
              if (widget.expanded) ...[
                const SizedBox(width: 12),
                Text(widget.label, style: TextStyle(color: fg, fontSize: 13, fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
