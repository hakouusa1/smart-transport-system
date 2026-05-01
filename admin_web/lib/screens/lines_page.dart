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
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          const SizedBox(height: 24),

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
}

// ─────────────────────────────────────────────────────────────
// LINE STOPS & PRICES MANAGEMENT DIALOG
// ─────────────────────────────────────────────────────────────
class _LineStopsPricesDialog extends StatefulWidget {
  final Map<String, dynamic> line;
  const _LineStopsPricesDialog({required this.line});

  @override
  State<_LineStopsPricesDialog> createState() => _LineStopsPricesDialogState();
}

class _LineStopsPricesDialogState extends State<_LineStopsPricesDialog> {
  List<Map<String, dynamic>> _lineStops = [];
  List<Map<String, dynamic>> _segmentPrices = [];
  List<Map<String, dynamic>> _allStops = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _loading = true);

      final stopsSnap = await AdminService.getStops().first;
      _allStops = stopsSnap;

      final lineStopsSnap = await AdminService.getLineStops(widget.line['lineId']).first;
      _lineStops = lineStopsSnap..sort((a, b) => (a['orderIndex'] as int).compareTo(b['orderIndex'] as int));

      final segmentsSnap = await AdminService.getSegmentPrices(widget.line['lineId']).first;
      _segmentPrices = segmentsSnap;

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _addStop(String stopId) async {
    final nextOrder = _lineStops.isEmpty ? 0 : _lineStops.last['orderIndex'] + 1;
    await AdminService.addStopToLine(
      lineId: widget.line['lineId'],
      stopId: stopId,
      orderIndex: nextOrder,
    );
    await _loadData();
  }

  Future<void> _removeStop(String lineStopId) async {
    await AdminService.removeStopFromLine(widget.line['lineId'], lineStopId);
    await _loadData();
  }

  Future<void> _setPrice(String fromStopId, String toStopId, double price) async {
    await AdminService.setSegmentPrice(
      lineId: widget.line['lineId'],
      fromStopId: fromStopId,
      toStopId: toStopId,
      price: price,
    );
    await _loadData();
  }

  String _getStopName(String stopId) {
    final stop = _allStops.firstWhere((s) => s['id'] == stopId, orElse: () => {'name': stopId});
    return stop['name'] ?? stopId;
  }

  double? _getSegmentPrice(String fromStopId, String toStopId) {
    final segment = _segmentPrices.firstWhere(
      (s) => s['fromStopId'] == fromStopId && s['toStopId'] == toStopId,
      orElse: () => {},
    );
    return segment['price']?.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.route, color: AppColors.navy, size: 24),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Gérer les arrêts et prix', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.dark)),
                  Text('${widget.line['name']}', style: const TextStyle(fontSize: 14, color: AppColors.sub)),
                ])),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ]),
              const SizedBox(height: 20),

              if (_loading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else if (_error != null)
                Expanded(child: Center(child: Text('Erreur: $_error', style: const TextStyle(color: AppColors.red))))
              else
                Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text('Ajouter un arrêt:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          Expanded(child: _buildStopDropdown()),
        ]),
        const SizedBox(height: 20),

        Expanded(child: ListView.builder(
          itemCount: _lineStops.length,
          itemBuilder: (context, index) {
            final lineStop = _lineStops[index];
            final stopId = lineStop['stopId'] as String;
            final stopName = _getStopName(stopId);

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
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.navy.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(child: Text('${index + 1}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.navy))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(stopName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.dark))),
                  IconButton(
                    icon: const Icon(Icons.delete, color: AppColors.red, size: 18),
                    onPressed: () => _removeStop(lineStop['id']),
                    tooltip: 'Supprimer cet arrêt',
                  ),
                ]),
              ),

              if (index < _lineStops.length - 1) ...[
                const SizedBox(height: 8),
                _buildSegmentPriceEditor(index),
                const SizedBox(height: 12),
              ],
            ]);
          },
        )),
      ],
    );
  }

  Widget _buildStopDropdown() {
    final availableStops = _allStops.where((stop) {
      final stopId = stop['id'] as String;
      return !_lineStops.any((ls) => ls['stopId'] == stopId);
    }).toList();

    if (availableStops.isEmpty) {
      return const Text('Tous les arrêts sont déjà ajoutés', style: TextStyle(color: AppColors.sub, fontSize: 12));
    }

    return DropdownButton<String>(
      hint: const Text('Sélectionner un arrêt'),
      items: availableStops.map((stop) {
        return DropdownMenuItem<String>(
          value: stop['id'],
          child: Text(stop['name'] ?? stop['id']),
        );
      }).toList(),
      onChanged: (stopId) {
        if (stopId != null) _addStop(stopId);
      },
    );
  }

  Widget _buildSegmentPriceEditor(int stopIndex) {
    final fromStop = _lineStops[stopIndex];
    final toStop = _lineStops[stopIndex + 1];
    final fromStopId = fromStop['stopId'] as String;
    final toStopId = toStop['stopId'] as String;
    final currentPrice = _getSegmentPrice(fromStopId, toStopId);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.arrow_downward, color: AppColors.green, size: 16),
          const SizedBox(width: 8),
          const Text('Prix du segment', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.green)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Text('${_getStopName(fromStopId)} → ${_getStopName(toStopId)}',
              style: const TextStyle(fontSize: 13, color: AppColors.dark))),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: TextFormField(
              initialValue: currentPrice?.toStringAsFixed(2) ?? '',
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: '0.00',
                suffixText: 'DA',
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              ),
              onFieldSubmitted: (value) {
                final price = double.tryParse(value);
                if (price != null && price > 0) {
                  _setPrice(fromStopId, toStopId, price);
                }
              },
            ),
          ),
        ]),
        if (currentPrice != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Prix actuel: ${currentPrice.toStringAsFixed(2)} DA',
                style: const TextStyle(fontSize: 11, color: AppColors.sub)),
          ),
      ]),
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
    if (_departureWilaya == null || _arrivalWilaya == null) return;

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
        'departure': _departureWilaya!.name,
        'arrival': _arrivalWilaya!.name,
        'name': '${_departureWilaya!.name} - ${_arrivalWilaya!.name}',
        'stops': stops,
        'basePrice': basePrice,
        'departureLat': _departureWilaya!.lat,
        'departureLng': _departureWilaya!.lng,
        'arrivalLat': _arrivalWilaya!.lat,
        'arrivalLng': _arrivalWilaya!.lng,
      });
    } else {
      await AdminService.createLine(
        departure: _departureWilaya!.name,
        arrival: _arrivalWilaya!.name,
        basePrice: basePrice,
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
      title: Text(
        _isEditing ? 'Modifier la ligne' : 'Créer une ligne',
        style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.dark),
      ),
      content: SizedBox(width: 460, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [

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

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 560),
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
