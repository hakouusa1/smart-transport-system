import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/admin_service.dart';
import '../services/geocoding_service.dart';

class StopsPage extends StatelessWidget {
  const StopsPage({super.key});

  void _createStop(BuildContext context) {
    showDialog(context: context, builder: (_) => const _StopFormDialog());
  }

  void _editStop(BuildContext context, Map<String, dynamic> stop) {
    showDialog(context: context, builder: (_) => _StopFormDialog(stop: stop));
  }

  void _confirmDelete(BuildContext context, Map<String, dynamic> stop) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer l\'arrêt ?'),
        content: Text(
            'Supprimer "${stop['name']}" ? Cette action est irréversible et peut affecter les lignes utilisant cet arrêt.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              await AdminService.deleteStop(stop['id']);
              if (ctx.mounted) Navigator.pop(ctx);
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
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('Arrêts',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.dark)),
            const Spacer(),
            FilledButton.icon(
              onPressed: () => _createStop(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nouvel arrêt'),
            ),
          ]),
          const SizedBox(height: 6),
          const Text(
            'Les arrêts sont des points de référence utilisés pour composer les lignes et tarifer les segments.',
            style: TextStyle(color: AppColors.sub, fontSize: 13),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: AdminService.getStops(),
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final stops = snap.data ?? [];
                if (stops.isEmpty) {
                  return Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.location_on_outlined, size: 48, color: AppColors.border),
                      const SizedBox(height: 12),
                      const Text('Aucun arrêt créé', style: TextStyle(color: AppColors.sub)),
                      const SizedBox(height: 16),
                      FilledButton(
                          onPressed: () => _createStop(context),
                          child: const Text('Créer le premier arrêt')),
                    ]),
                  );
                }

                return ListView.builder(
                  itemCount: stops.length,
                  itemBuilder: (_, i) {
                    final stop = stops[i];
                    final type = (stop['type'] as String?) ?? 'stop';
                     return Container(
                       margin: const EdgeInsets.only(bottom: 10),
                       padding: const EdgeInsets.all(16),
                       decoration: BoxDecoration(
                         color: AppColors.card,
                         borderRadius: BorderRadius.circular(12),
                         border: Border.all(color: AppColors.border),
                       ),
                       child: Row(children: [
                         Container(
                           width: 40, height: 40,
                           decoration: BoxDecoration(
                             color: AppColors.navy.withValues(alpha: 0.08),
                             borderRadius: BorderRadius.circular(10),
                           ),
                           child: const Icon(Icons.location_on_rounded,
                               color: AppColors.navy, size: 20),
                         ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(stop['name'] ?? '',
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.dark)),
                              const SizedBox(height: 2),
                              Text(_typeLabel(type),
                                  style: const TextStyle(
                                      fontSize: 12, color: AppColors.sub)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined,
                              color: AppColors.blue, size: 20),
                          tooltip: 'Modifier',
                          onPressed: () => _editStop(context, stop),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: AppColors.red, size: 20),
                          tooltip: 'Supprimer',
                          onPressed: () => _confirmDelete(context, stop),
                        ),
                      ]),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _typeLabel(String type) {
    switch (type) {
      case 'terminal':
        return 'Terminal / Gare';
      case 'station':
        return 'Station';
      case 'stop':
      default:
        return 'Arrêt intermédiaire';
    }
  }
}

class _StopFormDialog extends StatefulWidget {
  final Map<String, dynamic>? stop;
  const _StopFormDialog({this.stop});

  @override
  State<_StopFormDialog> createState() => _StopFormDialogState();
}

class _StopFormDialogState extends State<_StopFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  String _type = 'stop';
  bool _saving = false;
  String? _error;
  String? _originalName;
  double? _existingLat;
  double? _existingLng;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.stop?['name'] ?? '');
    _type = (widget.stop?['type'] as String?) ?? 'stop';
    _originalName = widget.stop?['name'] as String?;
    _existingLat = (widget.stop?['lat'] as num?)?.toDouble();
    _existingLng = (widget.stop?['lng'] as num?)?.toDouble();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final name = _nameCtrl.text.trim();
    final isEdit = widget.stop != null;
    final nameChanged = !isEdit || name != _originalName;
    final hasExistingCoords = _existingLat != null && _existingLng != null;

    double lat;
    double lng;

    if (nameChanged || !hasExistingCoords) {
      try {
        final geo = await GeocodingService.geocodeInAlgeria(name);
        if (geo == null) {
          if (mounted) {
            setState(() {
              _error =
                  'Aucun lieu trouvé en Algérie pour "$name". Essayez un autre nom.';
              _saving = false;
            });
          }
          return;
        }
        lat = geo.lat;
        lng = geo.lng;
      } on GeocodingException catch (e) {
        if (mounted) {
          setState(() {
            _error = e.reason;
            _saving = false;
          });
        }
        return;
      }
    } else {
      lat = _existingLat!;
      lng = _existingLng!;
    }

    try {
      if (!isEdit) {
        await AdminService.createStop(
            name: name, type: _type, lat: lat, lng: lng);
      } else {
        await AdminService.updateStop(widget.stop!['id'], {
          'name': name,
          'type': _type,
          'lat': lat,
          'lng': lng,
        });
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.stop != null;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.location_on, color: AppColors.navy, size: 22),
                  const SizedBox(width: 10),
                  Text(isEdit ? 'Modifier l\'arrêt' : 'Nouvel arrêt',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.dark)),
                  const Spacer(),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close)),
                ]),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Nom de l\'arrêt',
                    hintText: 'Ex: Bab El Oued',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
                ),
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.info_outline, size: 14, color: AppColors.sub),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'La localisation (GPS) sera détectée automatiquement à partir du nom.',
                      style: TextStyle(fontSize: 11, color: AppColors.sub),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'stop', child: Text('Arrêt intermédiaire')),
                    DropdownMenuItem(value: 'station', child: Text('Station')),
                    DropdownMenuItem(value: 'terminal', child: Text('Terminal / Gare')),
                  ],
                  onChanged: (v) => setState(() => _type = v ?? 'stop'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: AppColors.red, fontSize: 12)),
                ],
                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      child: const Text('Annuler')),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(isEdit ? 'Enregistrer' : 'Créer'),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
