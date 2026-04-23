import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme.dart';
import '../services/admin_service.dart';
import '../data/wilayas_data.dart';

class LinesPage extends StatelessWidget {
  const LinesPage({super.key});

  void _createLine(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const _LineFormDialog(),
    );
  }

  void _editLine(BuildContext context, Map<String, dynamic> line) {
    showDialog(
      context: context,
      builder: (ctx) => _LineFormDialog(line: line),
    );
  }

  void _confirmDelete(BuildContext context, Map<String, dynamic> line) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Supprimer la ligne ?'),
      content: Text('Supprimer "${line['name']}" ? Cette action est irréversible.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        FilledButton(
          onPressed: () { AdminService.deleteLine(line['lineId']); Navigator.pop(ctx); },
          style: FilledButton.styleFrom(backgroundColor: AppColors.red),
          child: const Text('Supprimer'),
        ),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.all(28), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('Lignes de transport', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.dark)),
        const Spacer(),
        FilledButton.icon(onPressed: () => _createLine(context), icon: const Icon(Icons.add, size: 18), label: const Text('Nouvelle ligne')),
      ]),
      const SizedBox(height: 6),
      const Text('Créez et gérez les lignes que les propriétaires peuvent sélectionner.', style: TextStyle(color: AppColors.sub, fontSize: 13)),
      const SizedBox(height: 24),

      Expanded(child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: AdminService.getLines(),
        builder: (_, snap) {
          final lines = snap.data ?? [];
          if (lines.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.route, size: 48, color: AppColors.border),
            const SizedBox(height: 12),
            const Text('Aucune ligne créée', style: TextStyle(color: AppColors.sub)),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => _createLine(context), child: const Text('Créer la première ligne')),
          ]));

          return ListView.builder(itemCount: lines.length, itemBuilder: (_, i) {
            final line = lines[i];
            final stops = (line['stops'] as List?)?.cast<String>() ?? [];
            final active = line['isActive'] ?? true;
            final hasCoords = line['departureLat'] != null && line['arrivalLat'] != null;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
              child: Row(children: [
                Container(width: 44, height: 44,
                  decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.route_rounded, color: AppColors.navy, size: 22)),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(line['departure'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.dark)),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(children: List.generate(4, (_) => Container(width: 4, height: 4, margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: const BoxDecoration(color: AppColors.sub, shape: BoxShape.circle))))),
                    Text(line['arrival'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.dark)),
                  ]),
                  if (stops.isNotEmpty)
                    Padding(padding: const EdgeInsets.only(top: 4),
                      child: Text('Arrêts: ${stops.join(" → ")}', style: const TextStyle(fontSize: 12, color: AppColors.sub))),
                  if (!hasCoords)
                    Padding(padding: const EdgeInsets.only(top: 4),
                      child: Row(children: const [
                        Icon(Icons.warning_amber_rounded, size: 12, color: AppColors.orange),
                        SizedBox(width: 4),
                        Text('Coordonnées manquantes', style: TextStyle(fontSize: 11, color: AppColors.orange)),
                      ])),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(6),
                    color: (active ? AppColors.green : AppColors.sub).withValues(alpha: 0.1),
                    border: Border.all(color: (active ? AppColors.green : AppColors.sub).withValues(alpha: 0.3))),
                  child: Text(active ? 'Active' : 'Inactive',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: active ? AppColors.green : AppColors.sub)),
                ),
                const SizedBox(width: 8),
                IconButton(icon: Icon(active ? Icons.pause_circle : Icons.play_circle, color: active ? AppColors.orange : AppColors.green, size: 22),
                  tooltip: active ? 'Désactiver' : 'Activer',
                  onPressed: () => AdminService.updateLine(line['lineId'], {'isActive': !active})),
                IconButton(icon: const Icon(Icons.edit_outlined, color: AppColors.blue, size: 20), tooltip: 'Modifier',
                  onPressed: () => _editLine(context, line)),
                IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.red, size: 20), tooltip: 'Supprimer',
                  onPressed: () => _confirmDelete(context, line)),
              ]),
            );
          });
        },
      )),
    ]));
  }
}

// ─────────────────────────────────────────────────────────────
// LINE FORM DIALOG — create (line == null) or edit (line != null)
// ─────────────────────────────────────────────────────────────
class _LineFormDialog extends StatefulWidget {
  final Map<String, dynamic>? line;
  const _LineFormDialog({this.line});

  @override
  State<_LineFormDialog> createState() => _LineFormDialogState();
}

class _LineFormDialogState extends State<_LineFormDialog> {
  late final TextEditingController _stopsCtrl;

  Wilaya? _departureWilaya;
  Wilaya? _arrivalWilaya;
  bool _loading = false;

  bool get _isEditing => widget.line != null;

  @override
  void initState() {
    super.initState();
    final line = widget.line;
    _stopsCtrl = TextEditingController(
      text: (line?['stops'] as List?)?.join(', ') ?? '',
    );
    // Pre-select wilayas from existing line data
    if (line != null) {
      final depName = line['departure'] as String?;
      final arrName = line['arrival'] as String?;
      if (depName != null) {
        _departureWilaya = kWilayas.where((w) => w.name == depName).firstOrNull;
      }
      if (arrName != null) {
        _arrivalWilaya = kWilayas.where((w) => w.name == arrName).firstOrNull;
      }
    }
  }

  @override
  void dispose() {
    _stopsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_departureWilaya == null || _arrivalWilaya == null) return;
    setState(() => _loading = true);

    final stops = _stopsCtrl.text.trim().isEmpty
        ? <String>[]
        : _stopsCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    if (_isEditing) {
      await AdminService.updateLine(widget.line!['lineId'], {
        'departure': _departureWilaya!.name,
        'arrival': _arrivalWilaya!.name,
        'name': '${_departureWilaya!.name} - ${_arrivalWilaya!.name}',
        'stops': stops,
        'departureLat': _departureWilaya!.lat,
        'departureLng': _departureWilaya!.lng,
        'arrivalLat': _arrivalWilaya!.lat,
        'arrivalLng': _arrivalWilaya!.lng,
      });
    } else {
      await AdminService.createLine(
        departure: _departureWilaya!.name,
        arrival: _arrivalWilaya!.name,
        stops: stops,
        adminId: FirebaseAuth.instance.currentUser?.uid ?? '',
        departureLat: _departureWilaya!.lat,
        departureLng: _departureWilaya!.lng,
        arrivalLat: _arrivalWilaya!.lat,
        arrivalLng: _arrivalWilaya!.lng,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _departureWilaya != null && _arrivalWilaya != null && !_loading;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(_isEditing ? 'Modifier la ligne' : 'Créer une ligne',
          style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.dark)),
      content: SizedBox(width: 460, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [

        // Departure wilaya picker
        _WilayaPickerField(
          label: 'Wilaya de départ *',
          icon: Icons.trip_origin,
          selected: _departureWilaya,
          onSelected: (w) => setState(() => _departureWilaya = w),
        ),
        const SizedBox(height: 14),

        // Arrival wilaya picker
        _WilayaPickerField(
          label: "Wilaya d'arrivée *",
          icon: Icons.place,
          selected: _arrivalWilaya,
          onSelected: (w) => setState(() => _arrivalWilaya = w),
        ),
        const SizedBox(height: 14),

        // Intermediate stops
        TextField(
          controller: _stopsCtrl,
          decoration: _inputDeco('Arrêts intermédiaires (optionnel)', 'Ex: Birkhadem, Bab Ezzouar'),
        ),

        // Coordinate preview
        if (_departureWilaya != null || _arrivalWilaya != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.navy.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.navy.withValues(alpha: 0.15)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Coordonnées GPS (auto)',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.sub)),
              const SizedBox(height: 6),
              if (_departureWilaya != null)
                Text('Départ: ${_departureWilaya!.lat.toStringAsFixed(4)}, ${_departureWilaya!.lng.toStringAsFixed(4)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.dark)),
              if (_arrivalWilaya != null)
                Text("Arrivée: ${_arrivalWilaya!.lat.toStringAsFixed(4)}, ${_arrivalWilaya!.lng.toStringAsFixed(4)}",
                    style: const TextStyle(fontSize: 12, color: AppColors.dark)),
            ]),
          ),
        ],
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          onPressed: canSubmit ? _submit : null,
          child: _loading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(_isEditing ? 'Enregistrer' : 'Créer'),
        ),
      ],
    );
  }

  static InputDecoration _inputDeco(String label, String hint) => InputDecoration(
    labelText: label, hintText: hint,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
  );
}

// ─────────────────────────────────────────────────────────────
// WILAYA PICKER FIELD — tappable tile that opens a search dialog
// ─────────────────────────────────────────────────────────────
class _WilayaPickerField extends StatelessWidget {
  final String label;
  final IconData icon;
  final Wilaya? selected;
  final ValueChanged<Wilaya> onSelected;

  const _WilayaPickerField({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelected,
  });

  Future<void> _openPicker(BuildContext context) async {
    final result = await showDialog<Wilaya>(
      context: context,
      builder: (ctx) => _WilayaSearchDialog(selectedCode: selected?.code),
    );
    if (result != null) onSelected(result);
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = selected != null;
    return InkWell(
      onTap: () => _openPicker(context),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasSelection ? AppColors.navy.withValues(alpha: 0.5) : AppColors.border,
          ),
          color: hasSelection ? AppColors.navy.withValues(alpha: 0.04) : Colors.transparent,
        ),
        child: Row(children: [
          Icon(icon, size: 20, color: hasSelection ? AppColors.navy : AppColors.sub),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 11, color: hasSelection ? AppColors.navy : AppColors.sub)),
            if (hasSelection)
              Text('${selected!.code.toString().padLeft(2, '0')} — ${selected!.name}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.dark)),
          ])),
          Icon(Icons.unfold_more, size: 18, color: AppColors.sub),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// WILAYA SEARCH DIALOG — full list of 58 wilayas with search
// ─────────────────────────────────────────────────────────────
class _WilayaSearchDialog extends StatefulWidget {
  final int? selectedCode;
  const _WilayaSearchDialog({this.selectedCode});

  @override
  State<_WilayaSearchDialog> createState() => _WilayaSearchDialogState();
}

class _WilayaSearchDialogState extends State<_WilayaSearchDialog> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = kWilayas.where((w) {
      if (_query.isEmpty) return true;
      return w.name.toLowerCase().contains(_query) ||
          w.code.toString() == _query;
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header
            Row(children: [
              const Icon(Icons.location_city, color: AppColors.navy, size: 20),
              const SizedBox(width: 8),
              const Expanded(child: Text('Choisir une wilaya',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.dark))),
              IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => Navigator.pop(context)),
            ]),
            const SizedBox(height: 10),

            // Search
            TextField(
              controller: _searchCtrl,
              autofocus: true,
              onChanged: (v) => setState(() => _query = v.toLowerCase().trim()),
              decoration: InputDecoration(
                hintText: 'Rechercher par nom ou code...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear, size: 18),
                        onPressed: () { _searchCtrl.clear(); setState(() => _query = ''); })
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border)),
              ),
            ),
            const SizedBox(height: 8),
            Text('${filtered.length} wilaya(s)', style: const TextStyle(fontSize: 11, color: AppColors.sub)),
            const SizedBox(height: 4),

            // List
            Expanded(child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final w = filtered[i];
                final isSelected = w.code == widget.selectedCode;
                return ListTile(
                  dense: true,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  selected: isSelected,
                  selectedColor: AppColors.navy,
                  selectedTileColor: AppColors.navy.withValues(alpha: 0.08),
                  leading: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.navy.withValues(alpha: 0.15)
                          : AppColors.border.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: Text(w.code.toString().padLeft(2, '0'),
                        style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: isSelected ? AppColors.navy : AppColors.sub,
                        )),
                  ),
                  title: Text(w.name,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 14,
                      )),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: AppColors.navy, size: 18)
                      : null,
                  onTap: () => Navigator.pop(context, w),
                );
              },
            )),
          ]),
        ),
      ),
    );
  }
}
