import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme.dart';
import '../services/admin_service.dart';

class BusesPage extends StatefulWidget {
  const BusesPage({super.key});

  @override
  State<BusesPage> createState() => _BusesPageState();
}

class _BusesPageState extends State<BusesPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final Stream<List<Map<String, dynamic>>> _allBusesStream;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 1, vsync: this);
    _allBusesStream = AdminService.getAllBuses();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= 600;
    final pad = isMobile ? 16.0 : 28.0;

    return Column(children: [
      Container(
        padding: EdgeInsets.fromLTRB(pad, pad, pad, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Gestion des bus',
              style: TextStyle(fontSize: isMobile ? 20 : 26, fontWeight: FontWeight.w700, color: AppColors.dark)),
          const SizedBox(height: 6),
          const Text('Validez les bus en attente et consultez tous les bus.',
              style: TextStyle(color: AppColors.sub, fontSize: 13)),
          const SizedBox(height: 16),
          TabBar(
            controller: _tabs,
            labelColor: AppColors.navy,
            unselectedLabelColor: AppColors.sub,
            indicatorColor: AppColors.navy,
            indicatorWeight: 2.5,
            tabs: const [
              Tab(text: 'Tous les bus'),
            ],
          ),
        ]),
      ),
      Expanded(
        child: TabBarView(controller: _tabs, children: [
          _BusList(stream: _allBusesStream),
        ]),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────
// BUS LIST
// ─────────────────────────────────────────────
class _BusList extends StatelessWidget {
  final Stream<List<Map<String, dynamic>>> stream;
  const _BusList({required this.stream});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= 600;
    final pad = isMobile ? 16.0 : 28.0;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.navy, strokeWidth: 2.5));
        }
        if (snap.hasError) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.red),
              const SizedBox(height: 12),
              Text(
                'Erreur de chargement: ${snap.error}',
                style: const TextStyle(color: AppColors.red),
                textAlign: TextAlign.center,
              ),
            ]),
          );
        }
        final buses = snap.data ?? [];
        if (buses.isEmpty) {
          return const Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.directions_bus_outlined, size: 48, color: AppColors.border),
              SizedBox(height: 12),
              Text('Aucun bus enregistré', style: TextStyle(color: AppColors.sub)),
            ]),
          );
        }
        return ListView.builder(
          padding: EdgeInsets.all(pad),
          itemCount: buses.length,
          itemBuilder: (_, i) => _BusCard(bus: buses[i]),
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

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= 600;
    final driverStatus = bus['driverStatus'] ?? 'offline';
    final validationStatus = bus['validationStatus'] ?? 'approved';

    final driverStatusColor = driverStatus == 'on_trip'
        ? AppColors.green
        : driverStatus == 'online'
            ? AppColors.blue
            : AppColors.sub;
    final driverStatusText = driverStatus == 'on_trip'
        ? 'En trajet'
        : driverStatus == 'online'
            ? 'En ligne'
            : 'Hors ligne';

    final validationColor = validationStatus == 'approved'
        ? AppColors.green
        : validationStatus == 'rejected'
            ? AppColors.red
            : AppColors.orange;
    final validationText = validationStatus == 'approved'
        ? 'Approuvé'
        : validationStatus == 'rejected'
            ? 'Rejeté'
            : 'En attente';

    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (ctx) => _BusDetailDialog(bus: bus),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.all(isMobile ? 14 : 16),
        decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border)),
        child: isMobile
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                      color: AppColors.navy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.directions_bus, color: AppColors.navy, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(bus['lineName'] ?? '--',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.dark)),
                  Text('${bus['busName'] ?? ''}  ${bus['busNumber'] ?? ''}',
                      style: const TextStyle(fontSize: 11, color: AppColors.sub)),
                ])),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                _badge(validationText, validationColor),
                const SizedBox(width: 6),
                _badge(driverStatusText, driverStatusColor),
              ]),
            ])
          : Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                    color: AppColors.navy.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10)),
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
            ]),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(text,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

// ─────────────────────────────────────────────
// BUS DETAIL DIALOG — zoomable images + per-doc review
// ─────────────────────────────────────────────
class _BusDetailDialog extends StatefulWidget {
  final Map<String, dynamic> bus;
  const _BusDetailDialog({required this.bus});
  @override
  State<_BusDetailDialog> createState() => _BusDetailDialogState();
}

class _BusDetailDialogState extends State<_BusDetailDialog> {
  late String _ligneStatus;
  late String _assuranceStatus;
  late final TextEditingController _ligneNoteCtrl;
  late final TextEditingController _assuranceNoteCtrl;
  bool _saving = false;
  bool _saved  = false;

  // Line change
  List<Map<String, dynamic>> _lines = [];
  String? _selectedLineId;
  bool _savingLine = false;
  bool _savedLine  = false;

  @override
  void initState() {
    super.initState();
    final bus = widget.bus;
    _ligneStatus     = bus['ligneValidationStatus'] as String? ?? 'pending';
    _assuranceStatus = bus['assuranceStatus']       as String? ?? 'pending';
    _ligneNoteCtrl    = TextEditingController(text: bus['ligneValidationNote'] as String? ?? '');
    _assuranceNoteCtrl = TextEditingController(text: bus['assuranceNote']      as String? ?? '');
    _loadLines();
  }

  Future<void> _loadLines() async {
    final snap = await FirebaseFirestore.instance
        .collection('lines')
        .orderBy('departure')
        .get();
    final lines = snap.docs.map((d) => d.data()).toList();
    if (!mounted) return;
    final currentLineId = widget.bus['lineId'] as String?;
    setState(() {
      _lines = lines;
      _selectedLineId = currentLineId;
    });
  }

  Map<String, dynamic>? get _selectedLine =>
      _selectedLineId == null ? null : _lines.where((l) => l['lineId'] == _selectedLineId).firstOrNull;

  Future<void> _saveLine() async {
    final line = _selectedLine;
    if (line == null) return;
    setState(() { _savingLine = true; _savedLine = false; });
    try {
      final fields = <String, dynamic>{
        'lineId':   line['lineId'],
        'lineName': line['name'],
      };
      if (line['departureLat'] != null) fields['departureLat'] = line['departureLat'];
      if (line['departureLng'] != null) fields['departureLng'] = line['departureLng'];
      if (line['arrivalLat']   != null) fields['arrivalLat']   = line['arrivalLat'];
      if (line['arrivalLng']   != null) fields['arrivalLng']   = line['arrivalLng'];
      await FirebaseFirestore.instance
          .collection('buses')
          .doc(widget.bus['busId'] as String)
          .update(fields);
      if (mounted) setState(() => _savedLine = true);
    } finally {
      if (mounted) setState(() => _savingLine = false);
    }
  }

  @override
  void dispose() {
    _ligneNoteCtrl.dispose();
    _assuranceNoteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() { _saving = true; _saved = false; });
    try {
      final hasIssue = _ligneStatus == 'issue' || _assuranceStatus == 'issue';
      await FirebaseFirestore.instance
          .collection('buses')
          .doc(widget.bus['busId'] as String)
          .update({
        'ligneValidationStatus': _ligneStatus,
        'ligneValidationNote':   _ligneNoteCtrl.text.trim(),
        'assuranceStatus':       _assuranceStatus,
        'assuranceNote':         _assuranceNoteCtrl.text.trim(),
        if (hasIssue) 'validationStatus': 'rejected',
      });
      if (mounted) setState(() => _saved = true);
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
              minScale: 0.5,
              maxScale: 8.0,
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
    final bus         = widget.bus;
    final ligneUrl    = bus['ligneValidationUrl'] as String?;
    final assuranceUrl = bus['assuranceUrl']      as String?;
    final vidangeTs   = bus['lastVidangeDate']    as Timestamp?;
    final vidangeDate = vidangeTs?.toDate();
    final vidangeKm   = bus['lastVidangeKm'];
    final note        = bus['validationNote']     as String?;

    final isMobile = MediaQuery.of(context).size.width <= 600;
    return Dialog(
      insetPadding: isMobile ? const EdgeInsets.all(12) : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 700, maxHeight: isMobile ? MediaQuery.of(context).size.height * 0.9 : double.infinity),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Header ──
            Row(children: [
              const Icon(Icons.directions_bus, color: AppColors.navy, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text('${bus['lineName'] ?? ''} — ${bus['busName'] ?? ''}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.dark)),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ]),
            Text('N° ${bus['busNumber'] ?? ''}',
                style: const TextStyle(color: AppColors.sub, fontSize: 13)),
            const Divider(height: 28),

            // ── Documents ──
            const Row(children: [
              Icon(Icons.folder_open, size: 16, color: AppColors.navy),
              SizedBox(width: 8),
              Text('Documents', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.dark)),
            ]),
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: isMobile
              ? [
                  // Stack documents vertically on mobile
                ]
              : [
                  Expanded(child: _docSection(
                    label: 'Validation de ligne', url: ligneUrl,
                    status: _ligneStatus, noteCtrl: _ligneNoteCtrl,
                    onStatus: (s) => setState(() { _ligneStatus = s; _saved = false; }),
                  )),
                  const SizedBox(width: 16),
                  Expanded(child: _docSection(
                    label: 'Assurance', url: assuranceUrl,
                    status: _assuranceStatus, noteCtrl: _assuranceNoteCtrl,
                    onStatus: (s) => setState(() { _assuranceStatus = s; _saved = false; }),
                  )),
                ]),
            if (isMobile) ...[
              _docSection(
                label: 'Validation de ligne', url: ligneUrl,
                status: _ligneStatus, noteCtrl: _ligneNoteCtrl,
                onStatus: (s) => setState(() { _ligneStatus = s; _saved = false; }),
              ),
              const SizedBox(height: 16),
              _docSection(
                label: 'Assurance', url: assuranceUrl,
                status: _assuranceStatus, noteCtrl: _assuranceNoteCtrl,
                onStatus: (s) => setState(() { _assuranceStatus = s; _saved = false; }),
              ),
            ],

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(_saved ? Icons.check : Icons.save_outlined, size: 18),
                label: Text(_saving ? 'Sauvegarde...' : _saved ? 'Sauvegardé !' : 'Sauvegarder la revue'),
                style: FilledButton.styleFrom(
                    backgroundColor: _saved ? AppColors.green : AppColors.navy),
              ),
            ),

            // ── Change Line ──
            const Divider(height: 28),
            const Row(children: [
              Icon(Icons.route, size: 16, color: AppColors.navy),
              SizedBox(width: 8),
              Text('Changer la ligne', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.dark)),
            ]),
            const SizedBox(height: 12),
            _lines.isEmpty
                ? const Center(child: CircularProgressIndicator(color: AppColors.navy, strokeWidth: 2))
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedLineId,
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      hint: const Text('Sélectionner une ligne', style: TextStyle(fontSize: 13)),
                      items: _lines.map((line) {
                        return DropdownMenuItem<String>(
                          value: line['lineId'] as String,
                          child: Text(line['name'] ?? '', style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (id) => setState(() { _selectedLineId = id; _savedLine = false; }),
                    ),
                  ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: (_savingLine || _selectedLine == null) ? null : _saveLine,
                icon: _savingLine
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(_savedLine ? Icons.check : Icons.swap_horiz, size: 18),
                label: Text(_savingLine ? 'Enregistrement...' : _savedLine ? 'Ligne mise à jour !' : 'Appliquer la ligne'),
                style: FilledButton.styleFrom(
                    backgroundColor: _savedLine ? AppColors.green : AppColors.navy),
              ),
            ),

            // ── Vidange ──
            if (vidangeDate != null || vidangeKm != null) ...[
              const Divider(height: 28),
              const Text('Dernière vidange',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.dark)),
              const SizedBox(height: 10),
              Wrap(spacing: 12, runSpacing: 8, children: [
                if (vidangeDate != null)
                  _infoChip(Icons.calendar_today,
                      '${vidangeDate.day.toString().padLeft(2, '0')}/${vidangeDate.month.toString().padLeft(2, '0')}/${vidangeDate.year}'),
                if (vidangeKm != null) _infoChip(Icons.speed, '$vidangeKm km'),
              ]),
            ],

            // ── Overall rejection note ──
            if (note != null && note.isNotEmpty) ...[
              const Divider(height: 28),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.info_outline, color: AppColors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(note,
                      style: const TextStyle(color: AppColors.red, fontSize: 13))),
                ]),
              ),
            ],
          ]),
        ),
      ),
    );
  }

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
      Stack(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: url != null
              ? Image.network(url,
                  height: 200, width: double.infinity, fit: BoxFit.cover,
                  loadingBuilder: (_, child, p) => p == null ? child
                      : const SizedBox(height: 200,
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                  errorBuilder: (_, __, ___) => _noDocWidget())
              : _noDocWidget(),
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
      Row(children: [
        Expanded(child: _toggleBtn(label: 'Conforme',  icon: Icons.check_circle, color: AppColors.green, selected: isOk,    onTap: () => onStatus('ok'))),
        const SizedBox(width: 8),
        Expanded(child: _toggleBtn(label: 'Problème',  icon: Icons.cancel,       color: AppColors.red,   selected: isIssue, onTap: () => onStatus('issue'))),
      ]),
      if (isIssue) ...[
        const SizedBox(height: 8),
        TextField(
          controller: noteCtrl,
          maxLines: 2,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Décrivez le problème visible par le propriétaire...',
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

  Widget _toggleBtn({
    required String label, required IconData icon,
    required Color color, required bool selected, required VoidCallback onTap,
  }) {
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
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              color: selected ? Colors.white : color)),
        ]),
      ),
    );
  }

  Widget _noDocWidget() => Container(
    height: 200, width: double.infinity,
    decoration: BoxDecoration(color: AppColors.border.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10)),
    child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.image_not_supported_outlined, color: AppColors.sub, size: 32),
      SizedBox(height: 6),
      Text('Aucun document', style: TextStyle(fontSize: 12, color: AppColors.sub)),
    ]),
  );

  Widget _infoChip(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: AppColors.navy),
      const SizedBox(width: 6),
      Text(text, style: const TextStyle(fontSize: 13, color: AppColors.dark)),
    ]),
  );
}
