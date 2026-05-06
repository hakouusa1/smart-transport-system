import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme.dart';
import '../services/admin_service.dart';

class NewBusesPage extends StatelessWidget {
  const NewBusesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= 600;
    final pad = isMobile ? 16.0 : 28.0;

    return Column(children: [
      Container(
        padding: EdgeInsets.fromLTRB(pad, pad, pad, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('✨ New Buses',
              style: TextStyle(fontSize: isMobile ? 20 : 26, fontWeight: FontWeight.w700, color: AppColors.dark)),
          const SizedBox(height: 6),
          const Text('Validez les nouvelles demandes de bus.',
              style: TextStyle(color: AppColors.sub, fontSize: 13)),
        ]),
      ),
      Expanded(
        child: ListView(
          padding: EdgeInsets.all(pad),
          children: [
            _SectionLabel(
              icon: Icons.hourglass_top_rounded,
              color: AppColors.orange,
              title: 'En attente de validation',
            ),
            const SizedBox(height: 12),
            _BusSectionStream(
              stream: AdminService.getPendingBuses(),
              emptyLabel: 'Aucun bus en attente de validation',
            ),
            const SizedBox(height: 28),
            _SectionLabel(
              icon: Icons.cancel_rounded,
              color: AppColors.red,
              title: 'Bus rejetés',
            ),
            const SizedBox(height: 12),
            _BusSectionStream(
              stream: AdminService.getRejectedBuses(),
              emptyLabel: 'Aucun bus rejeté',
            ),
          ],
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────
// SECTION LABEL
// ─────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  const _SectionLabel({required this.icon, required this.color, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      const SizedBox(width: 12),
      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.dark)),
    ]);
  }
}

// ─────────────────────────────────────────────
// BUS SECTION STREAM
// ─────────────────────────────────────────────
class _BusSectionStream extends StatelessWidget {
  final Stream<List<Map<String, dynamic>>> stream;
  final String emptyLabel;
  const _BusSectionStream({required this.stream, required this.emptyLabel});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(color: AppColors.navy, strokeWidth: 2.5),
            ),
          );
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(8),
            child: Text('Erreur: ${snap.error}',
                style: const TextStyle(color: AppColors.red, fontSize: 13)),
          );
        }
        final buses = snap.data ?? [];
        if (buses.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: Text(emptyLabel,
                  style: const TextStyle(color: AppColors.sub, fontSize: 13)),
            ),
          );
        }
        return Column(
          children: buses.map((b) => _BusCard(bus: b)).toList(),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// BUS CARD
// ─────────────────────────────────────────────
class _BusCard extends StatelessWidget {
  final Map<String, dynamic> bus;
  const _BusCard({required this.bus});

  void _openDetail(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _BusDetailDialog(bus: bus),
    );
  }

  void _confirmDelete(BuildContext context) {
    final name = '${bus['busName'] ?? ''} ${bus['busNumber'] ?? ''}'.trim();
    final messenger = ScaffoldMessenger.maybeOf(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer le bus ?',
            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.dark)),
        content: Text(
          'Voulez-vous vraiment supprimer "${name.isEmpty ? 'ce bus' : name}" ?\nCette action est irréversible.',
          style: const TextStyle(fontSize: 13, color: AppColors.sub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await AdminService.deleteBus(bus['busId'] as String);
                messenger?.showSnackBar(const SnackBar(
                  content: Text('Bus supprimé avec succès.'),
                  backgroundColor: AppColors.red,
                  behavior: SnackBarBehavior.floating,
                ));
              } catch (e) {
                messenger?.showSnackBar(SnackBar(
                  content: Text('Erreur : $e'),
                  backgroundColor: AppColors.red,
                  behavior: SnackBarBehavior.floating,
                ));
              }
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
    final driverStatus = bus['driverStatus'] ?? 'offline';
    final validationStatus = bus['validationStatus'] ?? 'pending';
    final isPending = validationStatus == 'pending';

    final driverStatusColor = driverStatus == 'on_trip'
        ? AppColors.green
        : driverStatus == 'online' ? AppColors.blue : AppColors.sub;
    final driverStatusText = driverStatus == 'on_trip'
        ? 'En trajet'
        : driverStatus == 'online' ? 'En ligne' : 'Hors ligne';

    final validationColor = validationStatus == 'approved'
        ? AppColors.green
        : validationStatus == 'rejected' ? AppColors.red : AppColors.orange;
    final validationText = validationStatus == 'approved'
        ? 'Approuvé'
        : validationStatus == 'rejected' ? 'Rejeté' : 'En attente';

    return InkWell(
      onTap: () => _openDetail(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.all(isMobile ? 14 : 16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: isMobile
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.navy.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.directions_bus, color: AppColors.navy, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(bus['lineName'] ?? '--',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.dark)),
                    Text('${bus['busName'] ?? ''}  ${bus['busNumber'] ?? ''}',
                        style: const TextStyle(fontSize: 11, color: AppColors.sub)),
                  ]),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                _badge(validationText, validationColor),
                const SizedBox(width: 6),
                _badge(driverStatusText, driverStatusColor),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                if (isPending)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _openDetail(context),
                      icon: const Icon(Icons.fact_check_outlined, size: 16),
                      label: const Text('Vérifier'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.navy,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _openDetail(context),
                      icon: const Icon(Icons.visibility_outlined, size: 16, color: AppColors.navy),
                      label: const Text('Voir détails', style: TextStyle(color: AppColors.navy)),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.navy.withValues(alpha: 0.1),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _confirmDelete(context),
                  icon: const Icon(Icons.delete_outline, color: AppColors.red, size: 22),
                  tooltip: 'Supprimer le bus',
                ),
              ]),
            ])
          : Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppColors.navy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.directions_bus, color: AppColors.navy, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(bus['lineName'] ?? '--',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.dark)),
                  Text('${bus['busName'] ?? ''}  ${bus['busNumber'] ?? ''}',
                      style: const TextStyle(fontSize: 12, color: AppColors.sub)),
                ]),
              ),
              _badge(validationText, validationColor),
              const SizedBox(width: 8),
              _badge(driverStatusText, driverStatusColor),
              const SizedBox(width: 12),
              if (isPending)
                FilledButton.icon(
                  onPressed: () => _openDetail(context),
                  icon: const Icon(Icons.fact_check_outlined, size: 16),
                  label: const Text('Vérifier'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                )
              else
                IconButton(
                  onPressed: () => _openDetail(context),
                  icon: const Icon(Icons.visibility_outlined, color: AppColors.navy, size: 22),
                  tooltip: 'Voir détails',
                ),
              IconButton(
                onPressed: () => _confirmDelete(context),
                icon: const Icon(Icons.delete_outline, color: AppColors.red, size: 22),
                tooltip: 'Supprimer le bus',
              ),
            ]),
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(6),
      color: color.withValues(alpha: 0.1),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// BUS DETAIL DIALOG
// Docs review + line picker → single Sauvegarder button decides approve/reject
// ─────────────────────────────────────────────────────────────────────────────
class _BusDetailDialog extends StatefulWidget {
  final Map<String, dynamic> bus;
  const _BusDetailDialog({required this.bus});
  @override
  State<_BusDetailDialog> createState() => _BusDetailDialogState();
}

class _BusDetailDialogState extends State<_BusDetailDialog> {
  // ── Doc review ──
  late String _ligneStatus;
  late String _assuranceStatus;
  late final TextEditingController _ligneNoteCtrl;
  late final TextEditingController _assuranceNoteCtrl;
  DateTime? _assuranceEndDate;

  // ── Line picker ──
  Map<String, dynamic>? _selectedLine;
  bool _showLinePicker = false;
  final _lineSearchCtrl = TextEditingController();
  String _lineQuery = '';

  // ── Save ──
  bool _saving = false;

  // ── Logic ──
  bool get _hasIssue => _ligneStatus == 'issue' || _assuranceStatus == 'issue';
  bool get _allReviewed =>
      (_ligneStatus == 'ok' || _ligneStatus == 'issue') &&
      ((_assuranceStatus == 'ok' && _assuranceEndDate != null) || _assuranceStatus == 'issue');
  // Can save: has an issue (auto-reject) OR all docs ok + line selected (auto-approve)
  bool get _canSave => _hasIssue || (_allReviewed && _selectedLine != null);

  @override
  void initState() {
    super.initState();
    final bus = widget.bus;
    _ligneStatus     = bus['ligneValidationStatus'] as String? ?? 'pending';
    _assuranceStatus = bus['assuranceStatus']       as String? ?? 'pending';
    _ligneNoteCtrl    = TextEditingController(text: bus['ligneValidationNote'] as String? ?? '');
    _assuranceNoteCtrl = TextEditingController(text: bus['assuranceNote']      as String? ?? '');
    final assuranceEndDate = bus['assuranceEndDate'];
    if (assuranceEndDate is Timestamp) {
      _assuranceEndDate = assuranceEndDate.toDate();
    }
  }

  @override
  void dispose() {
    _ligneNoteCtrl.dispose();
    _assuranceNoteCtrl.dispose();
    _lineSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final busId = widget.bus['busId'] as String;
      if (_hasIssue) {
        // ── Reject: persist doc notes + set status to rejected ──
        await FirebaseFirestore.instance.collection('buses').doc(busId).update({
          'ligneValidationStatus': _ligneStatus,
          'ligneValidationNote':   _ligneNoteCtrl.text.trim(),
          'assuranceStatus':       _assuranceStatus,
          'assuranceNote':         _assuranceNoteCtrl.text.trim(),
          'validationStatus':      'rejected',
        });
      } else {
        // ── Approve: persist doc notes then assign line + approve ──
        await FirebaseFirestore.instance.collection('buses').doc(busId).update({
          'ligneValidationStatus': 'ok',
          'ligneValidationNote':   '',
          'assuranceStatus':       'ok',
          'assuranceNote':         '',
          if (_assuranceEndDate != null) 'assuranceEndDate': Timestamp.fromDate(_assuranceEndDate!),
        });
        final line = _selectedLine!;
        await AdminService.setBusValidationStatus(
          busId,
          'approved',
          lineId:       line['lineId']     as String,
          lineName:     line['name']       as String,
          departureLat: (line['departureLat'] as num?)?.toDouble(),
          departureLng: (line['departureLng'] as num?)?.toDouble(),
          arrivalLat:   (line['arrivalLat']   as num?)?.toDouble(),
          arrivalLng:   (line['arrivalLng']   as num?)?.toDouble(),
        );
      }
      final label = _hasIssue ? 'Bus rejeté.' : 'Bus approuvé avec succès.';
      final color = _hasIssue ? AppColors.orange : AppColors.green;
      messenger?.showSnackBar(SnackBar(
        content: Text(label),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      messenger?.showSnackBar(SnackBar(
        content: Text('Erreur : $e'),
        backgroundColor: AppColors.red,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openZoom(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(),
        child: SizedBox.expand(
          child: Stack(children: [
            InteractiveViewer(
              minScale: 0.5, maxScale: 8.0,
              child: Center(child: Image.network(url, fit: BoxFit.contain)),
            ),
            Positioned(
              top: 12, right: 12,
              child: Material(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => Navigator.pop(ctx),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.close, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bus        = widget.bus;
    final ligneUrl   = bus['ligneValidationUrl'] as String?;
    final assuranceUrl = bus['assuranceUrl']     as String?;

    // Determine save button appearance
    final Color saveColor = _hasIssue ? AppColors.red : AppColors.green;
    final String saveLabel = _hasIssue ? 'Sauvegarder · Rejeter le bus' : 'Sauvegarder · Approuver le bus';

    final isMobile = MediaQuery.of(context).size.width <= 600;
    return Dialog(
      insetPadding: isMobile ? const EdgeInsets.all(12) : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 720, maxHeight: isMobile ? MediaQuery.of(context).size.height * 0.9 : 900),
        child: Column(children: [

          // ── Fixed header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
            child: Row(children: [
              const Icon(Icons.directions_bus, color: AppColors.navy, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${bus['lineName'] ?? ''} — ${bus['busName'] ?? ''}',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.dark)),
                  Text('N° ${bus['busNumber'] ?? ''}',
                      style: const TextStyle(color: AppColors.sub, fontSize: 12)),
                ]),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ]),
          ),
          const Divider(height: 24),

          // ── Scrollable body ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // ── Documents ──
                _sectionLabel(Icons.folder_open, 'Documents'),
                const SizedBox(height: 12),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: isMobile
                  ? [
                      // Handled below
                    ]
                  : [
                      Expanded(child: _docSection(
                        label: 'Validation de ligne', url: ligneUrl,
                        status: _ligneStatus, noteCtrl: _ligneNoteCtrl,
                        onStatus: (s) => setState(() => _ligneStatus = s),
                      )),
                      const SizedBox(width: 16),
                      Expanded(child: _docSection(
                        label: 'Assurance', url: assuranceUrl,
                        status: _assuranceStatus, noteCtrl: _assuranceNoteCtrl,
                        onStatus: (s) => setState(() => _assuranceStatus = s),
                      )),
                    ]),
                if (isMobile) ...[
                  _docSection(
                    label: 'Validation de ligne', url: ligneUrl,
                    status: _ligneStatus, noteCtrl: _ligneNoteCtrl,
                    onStatus: (s) => setState(() => _ligneStatus = s),
                  ),
                  const SizedBox(height: 16),
                  _docSection(
                    label: 'Assurance', url: assuranceUrl,
                    status: _assuranceStatus, noteCtrl: _assuranceNoteCtrl,
                    onStatus: (s) => setState(() => _assuranceStatus = s),
                  ),
                ],

                const Divider(height: 28),

                // ── Line picker ──
                _sectionLabel(Icons.route, 'Ligne assignée'),
                const SizedBox(height: 10),

                // Tile: shows selected line or "Choose" prompt
                InkWell(
                  onTap: () => setState(() => _showLinePicker = !_showLinePicker),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _selectedLine != null
                            ? AppColors.navy
                            : _showLinePicker ? AppColors.navy : AppColors.border,
                        width: _selectedLine != null || _showLinePicker ? 1.5 : 1,
                      ),
                      color: _selectedLine != null
                          ? AppColors.navy.withValues(alpha: 0.05)
                          : Colors.transparent,
                    ),
                    child: Row(children: [
                      Icon(
                        _selectedLine != null ? Icons.check_circle : Icons.route,
                        size: 18,
                        color: _selectedLine != null ? AppColors.navy : AppColors.sub,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _selectedLine != null
                              ? _selectedLine!['name'] as String
                              : 'Choisir une ligne...',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: _selectedLine != null ? FontWeight.w600 : FontWeight.w400,
                            color: _selectedLine != null ? AppColors.dark : AppColors.sub,
                          ),
                        ),
                      ),
                      Icon(
                        _showLinePicker ? Icons.expand_less : Icons.expand_more,
                        size: 20, color: AppColors.sub,
                      ),
                    ]),
                  ),
                ),

                // Inline line list (shown when expanded)
                if (_showLinePicker) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _lineSearchCtrl,
                    autofocus: true,
                    onChanged: (v) => setState(() => _lineQuery = v.toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Rechercher...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: _lineQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _lineSearchCtrl.clear();
                                setState(() => _lineQuery = '');
                              })
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.navy)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 230,
                    child: StreamBuilder<List<Map<String, dynamic>>>(
                      stream: AdminService.getLines(),
                      builder: (_, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                        }
                        final lines = (snap.data ?? []).where((l) {
                          final name = (l['name'] ?? '').toString().toLowerCase();
                          return name.contains(_lineQuery);
                        }).toList();
                        if (lines.isEmpty) {
                          return const Center(
                              child: Text('Aucune ligne trouvée',
                                  style: TextStyle(color: AppColors.sub, fontSize: 13)));
                        }
                        return ListView.builder(
                          itemCount: lines.length,
                          itemBuilder: (_, i) {
                            final line = lines[i];
                            final sel = _selectedLine?['lineId'] == line['lineId'];
                            return InkWell(
                              onTap: () => setState(() {
                                _selectedLine = line;
                                _showLinePicker = false;
                                _lineSearchCtrl.clear();
                                _lineQuery = '';
                              }),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                margin: const EdgeInsets.only(bottom: 4),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: sel
                                      ? AppColors.navy.withValues(alpha: 0.08)
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: sel ? AppColors.navy : AppColors.border,
                                    width: sel ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(children: [
                                  Icon(Icons.route, size: 16,
                                      color: sel ? AppColors.navy : AppColors.sub),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(line['name'] ?? '--',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: sel ? AppColors.navy : AppColors.dark,
                                        )),
                                  ),
                                  if (sel)
                                    const Icon(Icons.check, size: 16, color: AppColors.navy),
                                ]),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 8),
              ]),
            ),
          ),

          // ── Fixed bottom: Sauvegarder ──
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(children: [
              // Status hint
              Expanded(
                child: _canSave
                    ? Row(children: [
                        Icon(
                          _hasIssue ? Icons.cancel_outlined : Icons.check_circle_outline,
                          size: 16,
                          color: _hasIssue ? AppColors.red : AppColors.green,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _hasIssue
                                ? 'Le bus sera rejeté avec les notes de problème.'
                                : 'Le bus sera approuvé sur la ligne "${_selectedLine?['name']}".',
                            style: TextStyle(
                                fontSize: 12,
                                color: _hasIssue ? AppColors.red : AppColors.green),
                          ),
                        ),
                      ])
                    : Text(
                        _allReviewed && !_hasIssue
                            ? 'Choisissez une ligne pour approuver.'
                            : _ligneStatus != 'pending' && _assuranceStatus == 'ok' && _assuranceEndDate == null
                                ? 'Sélectionnez la date de fin d\'assurance.'
                                : 'Vérifiez les documents pour continuer.',
                        style: const TextStyle(fontSize: 12, color: AppColors.sub),
                      ),
              ),
              const SizedBox(width: 16),
              TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: (_canSave && !_saving) ? _save : null,
                style: FilledButton.styleFrom(
                  backgroundColor: saveColor,
                  disabledBackgroundColor: AppColors.border,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: _saving
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(saveLabel,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── Helpers ──

  Widget _sectionLabel(IconData icon, String title) => Row(children: [
    Icon(icon, size: 15, color: AppColors.navy),
    const SizedBox(width: 7),
    Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.dark)),
  ]);

  Widget _docSection({
    required String label,
    required String? url,
    required String status,
    required TextEditingController noteCtrl,
    required void Function(String) onStatus,
  }) {
    final isOk    = status == 'ok';
    final isIssue = status == 'issue';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.sub)),
      const SizedBox(height: 6),

      // Image
      Stack(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: url != null
              ? Image.network(url,
                  height: 190, width: double.infinity, fit: BoxFit.cover,
                  loadingBuilder: (_, child, p) => p == null
                      ? child
                      : const SizedBox(height: 190,
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                  errorBuilder: (_, __, ___) => _noDoc())
              : _noDoc(),
        ),
        if (url != null)
          Positioned(
            top: 8, right: 8,
            child: Tooltip(
              message: 'Agrandir',
              child: Material(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _openZoom(url),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.zoom_in, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),
          ),
      ]),

      const SizedBox(height: 8),

      // Conforme / Problème toggle
      Row(children: [
        Expanded(child: _toggle('Conforme', Icons.check_circle, AppColors.green, isOk,
            () => onStatus('ok'))),
        const SizedBox(width: 8),
        Expanded(child: _toggle('Problème', Icons.cancel, AppColors.red, isIssue,
            () => onStatus('issue'))),
      ]),

      // Date picker for assurance end if conforme
      if (label == 'Assurance' && isOk) ...[
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _assuranceEndDate ?? DateTime.now().add(const Duration(days: 365)),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
            );
            if (date != null) {
              setState(() => _assuranceEndDate = date);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              const Icon(Icons.calendar_today, size: 16, color: AppColors.sub),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _assuranceEndDate != null
                      ? '${_assuranceEndDate!.day}/${_assuranceEndDate!.month}/${_assuranceEndDate!.year}'
                      : 'Sélectionner la date de fin d\'assurance',
                  style: TextStyle(
                    fontSize: 13,
                    color: _assuranceEndDate != null ? AppColors.dark : AppColors.sub,
                  ),
                ),
              ),
            ]),
          ),
        ),
      ],

      // Reason field
      if (isIssue) ...[
        const SizedBox(height: 8),
        TextField(
          controller: noteCtrl,
          maxLines: 2,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Décrivez le problème...',
            hintStyle: const TextStyle(fontSize: 12, color: AppColors.sub),
            isDense: true,
            contentPadding: const EdgeInsets.all(10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.red)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.red.withValues(alpha: 0.5))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.red)),
          ),
        ),
      ],
    ]);
  }

  Widget _toggle(String label, IconData icon, Color color, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 14, color: selected ? Colors.white : color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: selected ? Colors.white : color)),
        ]),
      ),
    );
  }

  Widget _noDoc() => Container(
    height: 190, width: double.infinity,
    decoration: BoxDecoration(
        color: AppColors.border.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10)),
    child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.image_not_supported_outlined, color: AppColors.sub, size: 32),
      SizedBox(height: 6),
      Text('Aucun document', style: TextStyle(fontSize: 12, color: AppColors.sub)),
    ]),
  );
}
