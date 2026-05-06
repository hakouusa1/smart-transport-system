import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme.dart';
import '../services/admin_service.dart';

class OffersPage extends StatefulWidget {
  const OffersPage({super.key});
  @override
  State<OffersPage> createState() => _OffersPageState();
}

class _OffersPageState extends State<OffersPage> {
  bool _seeding = false;

  @override
  void initState() {
    super.initState();
    _autoSeedIfEmpty();
  }

  Future<void> _autoSeedIfEmpty() async {
    final snap = await FirebaseFirestore.instance
        .collection('subscription_plans')
        .limit(1)
        .get();
    if (snap.docs.isEmpty && mounted) {
      setState(() => _seeding = true);
      try {
        await AdminService.seedDefaultPlans();
      } finally {
        if (mounted) setState(() => _seeding = false);
      }
    }
  }

  void _confirmSeed() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Réinitialiser les plans ?',
            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.dark)),
        content: const Text(
          'Cette action supprimera tous les plans personnalisés et '
          'restaurera les 3 plans par défaut (Starter, Pro, Enterprise).\n\n'
          'Les abonnements existants ne seront pas affectés.',
          style: TextStyle(color: AppColors.sub, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _doSeed();
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text('Réinitialiser'),
          ),
        ],
      ),
    );
  }

  Future<void> _doSeed() async {
    setState(() => _seeding = true);
    try {
      await AdminService.forceSeedDefaultPlans();
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  void _createPlan(int existingCount) {
    showDialog(
      context: context,
      builder: (_) => _PlanFormDialog(existingCount: existingCount),
    );
  }

  void _editPlan(Map<String, dynamic> plan) {
    showDialog(
      context: context,
      builder: (_) => _PlanFormDialog(plan: plan),
    );
  }

  void _confirmDelete(Map<String, dynamic> plan) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer l\'offre ?',
            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.dark)),
        content: Text(
          'Supprimer "${plan['name']}" ?\nLes abonnés existants ne seront pas affectés.',
          style: const TextStyle(color: AppColors.sub, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              AdminService.deleteSubscriptionPlan(plan['id']);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= 600;
    final pad = isMobile ? 16.0 : 28.0;

    return Padding(
      padding: EdgeInsets.all(pad),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ──────────────────────────────────────────────────────────
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: AdminService.getSubscriptionPlans(),
          builder: (_, snap) {
            final plans = snap.data ?? [];
            if (isMobile) {
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Offres & Abonnements',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.dark)),
                const SizedBox(height: 4),
                const Text('Gérez les plans tarifaires visibles dans l\'application',
                    style: TextStyle(color: AppColors.sub, fontSize: 13)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: OutlinedButton.icon(
                    onPressed: _seeding ? null : _confirmSeed,
                    icon: _seeding
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.restart_alt, size: 18),
                    label: const Text('Plans par défaut'),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.sub),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: FilledButton.icon(
                    onPressed: () => _createPlan(plans.length),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Nouvelle offre'),
                  )),
                ]),
              ]);
            }

            return Row(children: [
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Offres & Abonnements',
                    style: TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.dark)),
                SizedBox(height: 4),
                Text('Gérez les plans tarifaires visibles dans l\'application',
                    style: TextStyle(color: AppColors.sub, fontSize: 13)),
              ]),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _seeding ? null : _confirmSeed,
                icon: _seeding
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.restart_alt, size: 18),
                label: const Text('Plans par défaut'),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.sub),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => _createPlan(plans.length),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nouvelle offre'),
              ),
            ]);
          },
        ),
        SizedBox(height: isMobile ? 16 : 28),

        // ── Plan Cards ──────────────────────────────────────────────────────
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: AdminService.getSubscriptionPlans(),
            builder: (_, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.lock_outline, size: 48, color: AppColors.red),
                    const SizedBox(height: 16),
                    const Text('Erreur d\'accès',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.red)),
                    const SizedBox(height: 8),
                    Text(
                      snap.error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.sub, fontSize: 12),
                    ),
                  ]),
                );
              }
              final plans = snap.data ?? [];
              if (plans.isEmpty) {
                return Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.workspace_premium, size: 56, color: AppColors.border),
                    const SizedBox(height: 16),
                    const Text('Aucune offre configurée',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.sub)),
                    const SizedBox(height: 8),
                    const Text(
                      'Cliquez sur "Plans par défaut" pour importer les plans de base,\n'
                      'ou créez une nouvelle offre.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.sub, fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _seeding ? null : _doSeed,
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Importer les plans par défaut'),
                    ),
                  ]),
                );
              }

              return LayoutBuilder(builder: (_, constraints) {
                final crossCount = constraints.maxWidth > 1100
                    ? 3
                    : constraints.maxWidth > 700
                        ? 2
                        : 1;
                return GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    mainAxisExtent: 300,
                  ),
                  itemCount: plans.length,
                  itemBuilder: (_, i) => _PlanCard(
                    plan: plans[i],
                    onEdit: () => _editPlan(plans[i]),
                    onDelete: () => _confirmDelete(plans[i]),
                  ),
                );
              });
            },
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════
// PLAN CARD
// ═══════════════════════════════════════════════════════
class _PlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PlanCard({required this.plan, required this.onEdit, required this.onDelete});

  Color get _color {
    final hex = (plan['colorHex'] as String? ?? '#5483B3').replaceAll('#', '');
    try {
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return AppColors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final price = (plan['priceDA'] as num?)?.toInt() ?? 0;
    final maxBuses = (plan['maxBuses'] as num?)?.toInt() ?? 0;
    final durationDays = (plan['durationDays'] as num?)?.toInt() ?? 30;
    final features = List<String>.from(plan['features'] ?? []);
    final recommended = plan['recommended'] == true;
    final color = _color;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: recommended ? color.withValues(alpha: 0.5) : AppColors.border,
          width: recommended ? 2 : 1,
        ),
        boxShadow: recommended
            ? [BoxShadow(color: color.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 4))]
            : const [],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Color bar + header
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 14, 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14), topRight: Radius.circular(14)),
          ),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.workspace_premium, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(plan['name'] ?? '',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700, color: color)),
                  if (recommended) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
                      child: const Text('Recommandé',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ]),
                const SizedBox(height: 2),
                Text(
                  maxBuses == 0 ? 'Bus illimités' : '$maxBuses bus maximum',
                  style: const TextStyle(fontSize: 11, color: AppColors.sub),
                ),
              ]),
            ),
            // Actions
            Row(children: [
              _ActionBtn(icon: Icons.edit_outlined, color: AppColors.blue, onTap: onEdit),
              const SizedBox(width: 6),
              _ActionBtn(icon: Icons.delete_outline, color: AppColors.red, onTap: onDelete),
            ]),
          ]),
        ),

        // Price + duration
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(
              _formatPrice(price),
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color),
            ),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                'DA / $durationDays j',
                style: const TextStyle(fontSize: 12, color: AppColors.sub),
              ),
            ),
          ]),
        ),

        const Divider(height: 1, color: AppColors.border, indent: 20, endIndent: 20),

        // Features
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
            child: features.isEmpty
                ? const Text('Aucune fonctionnalité',
                    style: TextStyle(color: AppColors.sub, fontSize: 13))
                : ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: features.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 5),
                    itemBuilder: (_, i) => Row(children: [
                      Icon(Icons.check_circle_rounded, size: 14, color: color),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(features[i],
                              style: const TextStyle(fontSize: 12, color: AppColors.text),
                              overflow: TextOverflow.ellipsis)),
                    ]),
                  ),
          ),
        ),
      ]),
    );
  }

  String _formatPrice(int price) {
    final s = price.toString();
    if (s.length <= 3) return s;
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// PLAN FORM DIALOG (Create / Edit)
// ═══════════════════════════════════════════════════════
class _PlanFormDialog extends StatefulWidget {
  final Map<String, dynamic>? plan;
  final int existingCount;
  const _PlanFormDialog({this.plan, this.existingCount = 0});

  @override
  State<_PlanFormDialog> createState() => _PlanFormDialogState();
}

class _PlanFormDialogState extends State<_PlanFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _maxBuses;
  late final TextEditingController _order;
  late final TextEditingController _duration;
  late final TextEditingController _hexCtrl;

  List<String> _features = [];
  String _colorHex = '#5483B3';
  bool _recommended = false;
  bool _saving = false;

  final _featureController = TextEditingController();

  static const _presetColors = [
    '#1565C0', '#F57C00', '#2E7D32', '#7C3AED',
    '#C62828', '#00838F', '#AD1457', '#4527A0',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.plan;
    _name = TextEditingController(text: p?['name'] ?? '');
    _price = TextEditingController(text: p != null ? '${p['priceDA'] ?? 0}' : '');
    _maxBuses = TextEditingController(
        text: p != null ? '${(p['maxBuses'] as num?)?.toInt() ?? 0}' : '');
    _order = TextEditingController(
        text: p != null
            ? '${(p['order'] as num?)?.toInt() ?? widget.existingCount}'
            : '${widget.existingCount}');
    _duration = TextEditingController(
        text: '${(p?['durationDays'] as num?)?.toInt() ?? 30}');
    _colorHex = (p?['colorHex'] as String?) ?? '#5483B3';
    _hexCtrl = TextEditingController(text: _colorHex);
    _recommended = p?['recommended'] == true;
    _features = List<String>.from(p?['features'] ?? []);
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _maxBuses.dispose();
    _order.dispose();
    _duration.dispose();
    _hexCtrl.dispose();
    _featureController.dispose();
    super.dispose();
  }

  Color get _parsedColor {
    final hex = _colorHex.replaceAll('#', '');
    try {
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return AppColors.blue;
    }
  }

  void _selectPreset(String hex) {
    setState(() {
      _colorHex = hex;
      _hexCtrl.text = hex;
    });
  }

  void _addFeature() {
    final f = _featureController.text.trim();
    if (f.isEmpty) return;
    setState(() {
      _features.add(f);
      _featureController.clear();
    });
  }

  void _removeFeature(int i) => setState(() => _features.removeAt(i));

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final data = {
        'name': _name.text.trim(),
        'priceDA': int.tryParse(_price.text.trim()) ?? 0,
        'maxBuses': int.tryParse(_maxBuses.text.trim()) ?? 0,
        'durationDays': int.tryParse(_duration.text.trim()) ?? 30,
        'features': _features,
        'colorHex': _colorHex,
        'recommended': _recommended,
        'order': int.tryParse(_order.text.trim()) ?? 0,
      };
      if (widget.plan == null) {
        await AdminService.createSubscriptionPlan(
          name: data['name'] as String,
          priceDA: data['priceDA'] as int,
          maxBuses: data['maxBuses'] as int,
          durationDays: data['durationDays'] as int,
          features: data['features'] as List<String>,
          colorHex: data['colorHex'] as String,
          recommended: data['recommended'] as bool,
          order: data['order'] as int,
        );
      } else {
        await AdminService.updateSubscriptionPlan(widget.plan!['id'], data);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.plan != null;
    final isMobile = MediaQuery.of(context).size.width <= 600;

    return Dialog(
      insetPadding: isMobile ? const EdgeInsets.all(12) : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 580, maxHeight: isMobile ? MediaQuery.of(context).size.height * 0.9 : 760),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16 : 28),
          child: Form(
            key: _formKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Title
              Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: _parsedColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.workspace_premium, color: _parsedColor, size: 22),
                ),
                const SizedBox(width: 12),
                Text(isEdit ? 'Modifier l\'offre' : 'Nouvelle offre',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.dark)),
                const Spacer(),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close)),
              ]),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 20),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Row 1: Name + Order
                    if (isMobile) ...[
                      _Field(
                        controller: _name,
                        label: 'Nom de l\'offre',
                        hint: 'ex: Pro',
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Requis' : null,
                      ),
                      const SizedBox(height: 12),
                      _Field(
                        controller: _order,
                        label: 'Ordre',
                        hint: '0',
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                    ] else
                      Row(children: [
                        Expanded(
                          flex: 3,
                          child: _Field(
                            controller: _name,
                            label: 'Nom de l\'offre',
                            hint: 'ex: Pro',
                            validator: (v) =>
                                v == null || v.trim().isEmpty ? 'Requis' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Field(
                            controller: _order,
                            label: 'Ordre',
                            hint: '0',
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          ),
                        ),
                      ]),
                    const SizedBox(height: 14),

                    // Row 2: Price + Duration + Max buses
                    if (isMobile) ...[
                      _Field(
                        controller: _price,
                        label: 'Prix (DA)',
                        hint: '5000',
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Requis' : null,
                        suffix: const Text('DA',
                            style: TextStyle(
                                color: AppColors.sub, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(height: 12),
                      _Field(
                        controller: _duration,
                        label: 'Durée (jours)',
                        hint: '30',
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          return (n == null || n < 1) ? 'Min 1' : null;
                        },
                        suffix: const Text('j',
                            style: TextStyle(
                                color: AppColors.sub, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(height: 12),
                      _Field(
                        controller: _maxBuses,
                        label: 'Max. bus (0=∞)',
                        hint: '10',
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                    ] else
                      Row(children: [
                        Expanded(
                          child: _Field(
                            controller: _price,
                            label: 'Prix (DA)',
                            hint: '5000',
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            validator: (v) =>
                                v == null || v.trim().isEmpty ? 'Requis' : null,
                            suffix: const Text('DA',
                                style: TextStyle(
                                    color: AppColors.sub, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Field(
                            controller: _duration,
                            label: 'Durée (jours)',
                            hint: '30',
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            validator: (v) {
                              final n = int.tryParse(v ?? '');
                              return (n == null || n < 1) ? 'Min 1' : null;
                            },
                            suffix: const Text('j',
                                style: TextStyle(
                                    color: AppColors.sub, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Field(
                            controller: _maxBuses,
                            label: 'Max. bus (0=∞)',
                            hint: '10',
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          ),
                        ),
                      ]),
                    const SizedBox(height: 20),

                    // Color picker
                    const Text('Couleur',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.dark)),
                    const SizedBox(height: 10),
                    Wrap(spacing: 10, runSpacing: 8, children: [
                      ..._presetColors.map((hex) {
                        final c = Color(
                            int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
                        final selected =
                            _colorHex.toUpperCase() == hex.toUpperCase();
                        return GestureDetector(
                          onTap: () => _selectPreset(hex),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? AppColors.dark
                                    : Colors.transparent,
                                width: 2.5,
                              ),
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                          color: c.withValues(alpha: 0.5),
                                          blurRadius: 8,
                                          spreadRadius: 2)
                                    ]
                                  : [],
                            ),
                            child: selected
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 16)
                                : null,
                          ),
                        );
                      }),
                      // Custom hex input — uses a controller so it syncs with preset selection
                      SizedBox(
                        width: 120,
                        height: 36,
                        child: TextFormField(
                          controller: _hexCtrl,
                          onChanged: (v) {
                            final clean = v.trim();
                            if (clean.length == 7 || clean.length == 6) {
                              final hex = clean.startsWith('#')
                                  ? clean
                                  : '#$clean';
                              setState(() => _colorHex = hex);
                            }
                          },
                          decoration: InputDecoration(
                            hintText: '#RRGGBB',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 9),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: AppColors.border)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: AppColors.border)),
                          ),
                          style: const TextStyle(
                              fontSize: 12, fontFamily: 'monospace'),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),

                    // Recommended toggle
                    GestureDetector(
                      onTap: () =>
                          setState(() => _recommended = !_recommended),
                      child: Row(children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 44,
                          height: 24,
                          decoration: BoxDecoration(
                            color: _recommended
                                ? _parsedColor
                                : AppColors.border,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: AnimatedAlign(
                            duration: const Duration(milliseconds: 200),
                            alignment: _recommended
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              width: 18,
                              height: 18,
                              margin: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                  color: Colors.white, shape: BoxShape.circle),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text('Marquer comme recommandé',
                            style: TextStyle(
                                fontSize: 14,
                                color: AppColors.dark,
                                fontWeight: FontWeight.w500)),
                      ]),
                    ),
                    const SizedBox(height: 20),

                    // Features
                    const Text('Fonctionnalités',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.dark)),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                        child: TextFormField(
                          controller: _featureController,
                          decoration: InputDecoration(
                            hintText: 'ex: Suivi GPS avancé',
                            hintStyle: const TextStyle(
                                color: AppColors.sub, fontSize: 13),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    const BorderSide(color: AppColors.border)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    const BorderSide(color: AppColors.border)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: AppColors.blue, width: 1.5)),
                          ),
                          onFieldSubmitted: (_) => _addFeature(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _addFeature,
                        style: FilledButton.styleFrom(
                          backgroundColor: _parsedColor,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          minimumSize: Size.zero,
                        ),
                        child:
                            const Icon(Icons.add, size: 18, color: Colors.white),
                      ),
                    ]),
                    if (_features.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ...List.generate(
                        _features.length,
                        (i) => Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: _parsedColor.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: _parsedColor.withValues(alpha: 0.2)),
                          ),
                          child: Row(children: [
                            Icon(Icons.check_circle_rounded,
                                size: 16, color: _parsedColor),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(_features[i],
                                    style: const TextStyle(
                                        fontSize: 13, color: AppColors.text))),
                            GestureDetector(
                              onTap: () => _removeFeature(i),
                              child: Icon(Icons.close,
                                  size: 16,
                                  color: AppColors.sub.withValues(alpha: 0.7)),
                            ),
                          ]),
                        ),
                      ),
                    ],
                  ]),
                ),
              ),

              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 16),

              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler')),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(backgroundColor: _parsedColor),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(isEdit ? 'Enregistrer' : 'Créer l\'offre',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType keyboardType;
  final List<TextInputFormatter> inputFormatters;
  final String? Function(String?)? validator;
  final Widget? suffix;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType = TextInputType.text,
    this.inputFormatters = const [],
    this.validator,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.dark)),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.sub, fontSize: 13),
          suffix: suffix,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.blue, width: 1.5)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.red)),
        ),
      ),
    ]);
  }
}
