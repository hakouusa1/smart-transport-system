import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme.dart';
import '../services/admin_service.dart';
import '../services/geocoding_service.dart';
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

  void _manageStopsPrices(BuildContext context, Map<String, dynamic> line) {
    showDialog(
      context: context,
      builder: (ctx) => _LineStopsPricesDialog(line: line),
    );
  }

  void _confirmDelete(BuildContext context, Map<String, dynamic> line) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= 600;
    final pad = isMobile ? 16.0 : 28.0;

    return Padding(
      padding: EdgeInsets.all(pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMobile) ...[
            Text('Lignes de transport', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.dark)),
            const SizedBox(height: 4),
            const Text(
              'Bidirectionnelle : aller et retour automatiquement.',
              style: TextStyle(color: AppColors.sub, fontSize: 12),
            ),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: FilledButton.icon(
              onPressed: () => _createLine(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nouvelle ligne'),
            )),
          ] else ...[
            Row(children: [
              const Text('Lignes de transport', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.dark)),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _createLine(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nouvelle ligne'),
              ),
            ]),
            const SizedBox(height: 6),
            const Text(
              'Chaque ligne est bidirectionnelle : elle couvre le trajet aller et retour automatiquement.',
              style: TextStyle(color: AppColors.sub, fontSize: 13),
            ),
          ],
          const SizedBox(height: 20),

          Expanded(child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: AdminService.getLines(),
            builder: (_, snap) {
              final lines = snap.data ?? [];
              if (lines.isEmpty) {
                return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.route, size: 48, color: AppColors.border),
                  const SizedBox(height: 12),
                  const Text('Aucune ligne créée', style: TextStyle(color: AppColors.sub)),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: () => _createLine(context), child: const Text('Créer la première ligne')),
                ]));
              }

              return ListView.builder(itemCount: lines.length, itemBuilder: (_, i) {
                final line = lines[i];
                final stops = (line['stops'] as List?)?.cast<String>() ?? [];
                final active = line['isActive'] ?? true;
                final hasCoords = line['departureLat'] != null && line['arrivalLat'] != null;

                if (isMobile) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Route name
                      Row(children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.navy.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.route_rounded, color: AppColors.navy, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(
                          '${line['departure'] ?? ''} ⇄ ${line['arrival'] ?? ''}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.dark),
                        )),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: (active ? AppColors.green : AppColors.sub).withValues(alpha: 0.1),
                          ),
                          child: Text(active ? 'Active' : 'Inactive',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: active ? AppColors.green : AppColors.sub)),
                        ),
                      ]),
                      if (stops.isNotEmpty) ...[const SizedBox(height: 6),
                        Text('Arrêts: ${stops.join(" → ")}', style: const TextStyle(fontSize: 11, color: AppColors.sub)),
                      ],
                      const SizedBox(height: 6),
                      Row(children: [
                        const Icon(Icons.payments_outlined, size: 12, color: AppColors.green),
                        const SizedBox(width: 4),
                        Text(
                          (line['basePrice'] as num?) != null
                              ? '${(line['basePrice'] as num).toStringAsFixed(0)} DA'
                              : '---',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                            color: (line['basePrice'] as num?) != null ? AppColors.green : AppColors.orange),
                        ),
                        if (!hasCoords) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.warning_amber_rounded, size: 12, color: AppColors.orange),
                          const SizedBox(width: 2),
                          const Text('GPS manquant', style: TextStyle(fontSize: 10, color: AppColors.orange)),
                        ],
                      ]),
                      const SizedBox(height: 10),
                      // Actions row
                      Row(children: [
                        _mobileAction(active ? Icons.pause_circle : Icons.play_circle,
                          active ? AppColors.orange : AppColors.green, active ? 'Pause' : 'Activer',
                          () => AdminService.updateLine(line['lineId'], {'isActive': !active})),
                        const SizedBox(width: 6),
                        _mobileAction(Icons.route, AppColors.green, 'Arrêts',
                          () => _manageStopsPrices(context, line)),
                        const SizedBox(width: 6),
                        _mobileAction(Icons.edit_outlined, AppColors.blue, 'Modifier',
                          () => _editLine(context, line)),
                        const SizedBox(width: 6),
                        _mobileAction(Icons.delete_outline, AppColors.red, 'Suppr.',
                          () => _confirmDelete(context, line)),
                      ]),
                    ]),
                  );
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.navy.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.route_rounded, color: AppColors.navy, size: 22),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(line['departure'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.dark)),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.sync_alt, size: 16, color: AppColors.sub),
                        ),
                        Text(line['arrival'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.dark)),
                      ]),
                      if (stops.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('Arrêts: ${stops.join(" → ")}', style: const TextStyle(fontSize: 12, color: AppColors.sub)),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(children: [
                          const Icon(Icons.payments_outlined, size: 12, color: AppColors.green),
                          const SizedBox(width: 4),
                          Text(
                            (line['basePrice'] as num?) != null
                                ? 'Prix de base: ${(line['basePrice'] as num).toStringAsFixed(2)} DA'
                                : 'Prix de base: ---',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: (line['basePrice'] as num?) != null ? AppColors.green : AppColors.orange,
                            ),
                          ),
                        ]),
                      ),
                      if (!hasCoords)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Row(children: [
                            Icon(Icons.warning_amber_rounded, size: 12, color: AppColors.orange),
                            SizedBox(width: 4),
                            Text('Coordonnées manquantes', style: TextStyle(fontSize: 11, color: AppColors.orange)),
                          ]),
                        ),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: (active ? AppColors.green : AppColors.sub).withValues(alpha: 0.1),
                        border: Border.all(color: (active ? AppColors.green : AppColors.sub).withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        active ? 'Active' : 'Inactive',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: active ? AppColors.green : AppColors.sub),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(active ? Icons.pause_circle : Icons.play_circle, color: active ? AppColors.orange : AppColors.green, size: 22),
                      tooltip: active ? 'Désactiver' : 'Activer',
                      onPressed: () => AdminService.updateLine(line['lineId'], {'isActive': !active}),
                    ),
                    IconButton(
                      icon: const Icon(Icons.route, color: AppColors.green, size: 20),
                      tooltip: 'Gérer arrêts et prix',
                      onPressed: () => _manageStopsPrices(context, line),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: AppColors.blue, size: 20),
                      tooltip: 'Modifier',
                      onPressed: () => _editLine(context, line),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.red, size: 20),
                      tooltip: 'Supprimer',
                      onPressed: () => _confirmDelete(context, line),
                    ),
                  ]),
                );
              });
            },
          )),
        ],
      ),
    );
  }

  Widget _mobileAction(IconData icon, Color color, String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color)),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// LINE STOPS & PRICES MANAGEMENT DIALOG
// ─────────────────────────────────────────────────────────────
class _StopEntry {
  String name;
  double? lat;
  double? lng;
  final TextEditingController priceCtrl;
  _StopEntry({required this.name, this.lat, this.lng, double priceToNext = 0.0})
      : priceCtrl = TextEditingController(
            text: priceToNext > 0 ? priceToNext.toStringAsFixed(0) : '');
}

class _LineStopsPricesDialog extends StatefulWidget {
  final Map<String, dynamic> line;
  const _LineStopsPricesDialog({required this.line});
  @override
  State<_LineStopsPricesDialog> createState() => _LineStopsPricesDialogState();
}

class _LineStopsPricesDialogState extends State<_LineStopsPricesDialog> {
  final List<_StopEntry> _stops = [];
  final _newNameCtrl = TextEditingController();
  List<GeocodeResult> _suggestions = [];
  Timer? _debounce;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final raw = (widget.line['lineStopsData'] as List?)?.cast<Map>() ?? [];
    for (final s in raw) {
      _stops.add(_StopEntry(
        name: s['name'] as String? ?? '',
        lat: (s['lat'] as num?)?.toDouble(),
        lng: (s['lng'] as num?)?.toDouble(),
        priceToNext: (s['priceToNext'] as num?)?.toDouble() ?? 0.0,
      ));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _newNameCtrl.dispose();
    for (final s in _stops) { s.priceCtrl.dispose(); }
    super.dispose();
  }

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    if (val.trim().length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final results = await GeocodingService.suggestPlaces(val.trim());
      if (mounted) setState(() => _suggestions = results);
    });
  }

  void _addStopFromSuggestion(GeocodeResult result) {
    final shortName = result.resolvedName.split(',').first.trim();
    setState(() {
      _stops.add(_StopEntry(name: shortName, lat: result.lat, lng: result.lng));
      _newNameCtrl.clear();
      _suggestions = [];
    });
  }

  void _addStop() {
    final name = _newNameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _stops.add(_StopEntry(name: name));
      _newNameCtrl.clear();
      _suggestions = [];
    });
  }

  void _removeStop(int index) {
    setState(() {
      _stops[index].priceCtrl.dispose();
      _stops.removeAt(index);
    });
  }

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    try {
      final data = _stops.map((s) => {
        'name': s.name,
        'priceToNext': double.tryParse(s.priceCtrl.text.replaceAll(',', '.')) ?? 0.0,
        if (s.lat != null) 'lat': s.lat,
        if (s.lng != null) 'lng': s.lng,
      }).toList();
      await AdminService.updateLine(widget.line['lineId'], {'lineStopsData': data});
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() { _error = e.toString(); _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= 600;
    return Dialog(
      insetPadding: isMobile ? const EdgeInsets.all(12) : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 600, maxHeight: isMobile ? MediaQuery.of(context).size.height * 0.85 : 700),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.route, color: AppColors.navy, size: 24),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Gérer les arrêts et prix',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.dark)),
                  Text('${widget.line['name']}',
                      style: const TextStyle(fontSize: 13, color: AppColors.sub)),
                ])),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ]),
              const SizedBox(height: 20),

              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _newNameCtrl,
                    decoration: InputDecoration(
                      hintText: 'Rechercher un lieu (ex: Djebahia, Bouira...)',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: _onSearchChanged,
                    onSubmitted: (_) => _addStop(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _addStop,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Ajouter'),
                ),
              ]),

              if (_suggestions.isNotEmpty) ...[
                const SizedBox(height: 4),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _suggestions.map((r) {
                      final parts = r.resolvedName.split(',');
                      final main = parts.first.trim();
                      final sub = parts.length > 1 ? parts.sublist(1).join(',').trim() : '';
                      return InkWell(
                        onTap: () => _addStopFromSuggestion(r),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(children: [
                            const Icon(Icons.location_on, size: 16, color: AppColors.navy),
                            const SizedBox(width: 10),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(main, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.dark)),
                              if (sub.isNotEmpty)
                                Text(sub, style: const TextStyle(fontSize: 11, color: AppColors.sub), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ])),
                          ]),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              Expanded(
                child: _stops.isEmpty
                    ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.location_on_outlined, size: 48, color: AppColors.border),
                        SizedBox(height: 8),
                        Text('Aucun arrêt ajouté', style: TextStyle(color: AppColors.sub)),
                      ]))
                    : ListView.builder(
                        itemCount: _stops.length,
                        itemBuilder: (_, i) {
                          final stop = _stops[i];
                          final isLast = i == _stops.length - 1;
                          return Column(children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(children: [
                                Container(
                                  width: 30, height: 30,
                                  decoration: BoxDecoration(
                                    color: AppColors.navy.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Center(child: Text('${i + 1}',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.navy))),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Text(stop.name,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.dark))),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppColors.red, size: 18),
                                  onPressed: () => _removeStop(i),
                                ),
                              ]),
                            ),
                            if (!isLast) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.green.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.green.withValues(alpha: 0.2)),
                                ),
                                child: Row(children: [
                                  const Icon(Icons.arrow_downward, size: 14, color: AppColors.green),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(
                                    '${stop.name} → ${_stops[i + 1].name}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.dark),
                                  )),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 90,
                                    child: TextField(
                                      controller: stop.priceCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        hintText: '0',
                                        suffixText: 'DA',
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                      ),
                                    ),
                                  ),
                                ]),
                              ),
                              const SizedBox(height: 6),
                            ],
                          ]);
                        },
                      ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: AppColors.red, fontSize: 12)),
              ],
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Enregistrer'),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
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
  late final TextEditingController _basePriceCtrl;

  Wilaya? _departureWilaya;
  Wilaya? _arrivalWilaya;
  bool _loading = false;
  String? _priceError;

  bool get _isEditing => widget.line != null;

  @override
  void initState() {
    super.initState();
    final line = widget.line;
    _stopsCtrl = TextEditingController(
      text: (line?['stops'] as List?)?.join(', ') ?? '',
    );
    final existingPrice = (line?['basePrice'] as num?)?.toDouble();
    _basePriceCtrl = TextEditingController(
      text: existingPrice != null ? existingPrice.toStringAsFixed(2) : '',
    );
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
    _basePriceCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final dep = _departureWilaya;
    final arr = _arrivalWilaya;
    if (dep == null || arr == null) return;

    final priceText = _basePriceCtrl.text.trim().replaceAll(',', '.');
    final basePrice = double.tryParse(priceText);
    if (basePrice == null || basePrice <= 0) {
      setState(() => _priceError = 'Saisissez un prix de base valide (> 0)');
      return;
    }

    setState(() {
      _loading = true;
      _priceError = null;
    });

    final stops = _stopsCtrl.text.trim().isEmpty
        ? <String>[]
        : _stopsCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    if (_isEditing) {
      await AdminService.updateLine(widget.line!['lineId'], {
        'departure': dep.name,
        'arrival': arr.name,
        'name': '${dep.name} - ${arr.name}',
        'stops': stops,
        'basePrice': basePrice,
        'departureLat': dep.lat,
        'departureLng': dep.lng,
        'arrivalLat': arr.lat,
        'arrivalLng': arr.lng,
      });
    } else {
      await AdminService.createLine(
        departure: dep.name,
        arrival: arr.name,
        basePrice: basePrice,
        stops: stops,
        adminId: FirebaseAuth.instance.currentUser?.uid ?? '',
        departureLat: dep.lat,
        departureLng: dep.lng,
        arrivalLat: arr.lat,
        arrivalLng: arr.lng,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _departureWilaya != null && _arrivalWilaya != null && !_loading;

    final isMobile = MediaQuery.of(context).size.width <= 600;
    return AlertDialog(
      insetPadding: isMobile ? const EdgeInsets.all(16) : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        _isEditing ? 'Modifier la ligne' : 'Créer une ligne',
        style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.dark),
      ),
      content: SizedBox(width: isMobile ? double.infinity : 460, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [

        _WilayaPickerField(
          label: 'Wilaya de départ *',
          icon: Icons.trip_origin,
          selected: _departureWilaya,
          onSelected: (w) => setState(() => _departureWilaya = w),
        ),
        const SizedBox(height: 14),

        _WilayaPickerField(
          label: "Wilaya d'arrivée *",
          icon: Icons.place,
          selected: _arrivalWilaya,
          onSelected: (w) => setState(() => _arrivalWilaya = w),
        ),
        const SizedBox(height: 14),

        TextField(
          controller: _stopsCtrl,
          decoration: _inputDeco('Arrêts intermédiaires (optionnel)', 'Ex: Birkhadem, Bab Ezzouar'),
        ),
        const SizedBox(height: 14),

        TextField(
          controller: _basePriceCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: _inputDeco('Prix de base (ligne complète) *', 'Ex: 250')
              .copyWith(suffixText: 'DA', errorText: _priceError),
          onChanged: (_) {
            if (_priceError != null) setState(() => _priceError = null);
          },
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, left: 4),
          child: Text(
            'Tarif pour le trajet complet départ → arrivée. Les segments intermédiaires se gèrent depuis "Gérer arrêts et prix".',
            style: TextStyle(fontSize: 11, color: AppColors.sub),
          ),
        ),

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
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_isEditing ? 'Enregistrer' : 'Créer'),
        ),
      ],
    );
  }

  static InputDecoration _inputDeco(String label, String hint) => InputDecoration(
    labelText: label, hintText: hint,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.border),
    ),
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
              Text(
                '${selected!.code.toString().padLeft(2, '0')} — ${selected!.name}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.dark),
              ),
          ])),
          const Icon(Icons.unfold_more, size: 18, color: AppColors.sub),
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

    final isMobile = MediaQuery.of(context).size.width <= 600;
    return Dialog(
      insetPadding: isMobile ? const EdgeInsets.all(12) : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 400, maxHeight: isMobile ? MediaQuery.of(context).size.height * 0.7 : 560),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.location_city, color: AppColors.navy, size: 20),
              const SizedBox(width: 8),
              const Expanded(child: Text('Choisir une wilaya',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.dark))),
              IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => Navigator.pop(context)),
            ]),
            const SizedBox(height: 10),

            TextField(
              controller: _searchCtrl,
              autofocus: true,
              onChanged: (v) => setState(() => _query = v.toLowerCase().trim()),
              decoration: InputDecoration(
                hintText: 'Rechercher par nom ou code...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () { _searchCtrl.clear(); setState(() => _query = ''); },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text('${filtered.length} wilaya(s)', style: const TextStyle(fontSize: 11, color: AppColors.sub)),
            const SizedBox(height: 4),

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
                    child: Text(
                      w.code.toString().padLeft(2, '0'),
                      style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: isSelected ? AppColors.navy : AppColors.sub,
                      ),
                    ),
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
