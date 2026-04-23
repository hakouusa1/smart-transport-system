import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../data/wilayas_data.dart';
import '../models/bus_model.dart';
import '../services/supabase_storage_service.dart';
import '../widgets/bus_loading_indicator.dart';


class AddBusScreen extends StatefulWidget {
  final Bus? busToEdit;

  const AddBusScreen({super.key, this.busToEdit});

  @override
  State<AddBusScreen> createState() => _AddBusScreenState();
}

class _AddBusScreenState extends State<AddBusScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  late final TextEditingController _busNameController;
  late final TextEditingController _busNumberController;
  late final TextEditingController _driverEmailController;
  late final TextEditingController _driverPasswordController;
  late final TextEditingController _salaryController;
  final TextEditingController _receveurController = TextEditingController();
  final TextEditingController _lastVidangeKmController = TextEditingController();
  final TextEditingController _currentKmController = TextEditingController();
  late bool _isActive;

  // Trips
  int _numberOfTrips = 1;
  List<TimeOfDay?> _tripSchedules = [null];

  // Salary types
  String _chauffeurSalaryType = 'monthly';
  String _receveurSalaryType = 'monthly';

  // Departure / arrival wilayas
  Wilaya? _selectedDepartureWilaya;
  Wilaya? _selectedArrivalWilaya;

  // Documents (new bus only)
  XFile? _ligneValidationFile;
  XFile? _assuranceFile;
  bool _uploadingDocs = false;

  // Assurance expiry (new bus only, optional)
  DateTime? _insuranceEndDate;

  // Vidange (new bus only, optional)
  DateTime? _lastVidangeDate;

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool get _isEditing => widget.busToEdit != null;

  @override
  void initState() {
    super.initState();
    _busNameController =
        TextEditingController(text: widget.busToEdit?.busName ?? '');
    _busNumberController =
        TextEditingController(text: widget.busToEdit?.busNumber ?? '');
    _driverEmailController = TextEditingController();
    _driverPasswordController = TextEditingController();
    _salaryController = TextEditingController();
    _isActive = widget.busToEdit?.isActive ?? true;
    if (widget.busToEdit?.currentKm != null) {
      _currentKmController.text = widget.busToEdit!.currentKm.toString();
    }
    // Load trip schedules from existing bus
    final existing = widget.busToEdit?.allSchedules ?? [];
    _numberOfTrips = existing.isNotEmpty
        ? existing.length
        : (widget.busToEdit?.numberOfTrips ?? 1);
    _tripSchedules = List.generate(_numberOfTrips, (i) {
      if (i < existing.length) {
        final parts = existing[i].split(':');
        if (parts.length == 2) {
          return TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 0,
            minute: int.tryParse(parts[1]) ?? 0,
          );
        }
      }
      return null;
    });
    _chauffeurSalaryType = widget.busToEdit?.chauffeurSalaryType ?? 'monthly';
    _receveurSalaryType = widget.busToEdit?.receveurSalaryType ?? 'monthly';

    // Pre-populate departure wilaya from stored coords (exact match)
    final dLat = widget.busToEdit?.departureLat;
    final dLng = widget.busToEdit?.departureLng;
    if (dLat != null && dLng != null) {
      try {
        _selectedDepartureWilaya = kWilayas.firstWhere(
          (w) => (w.lat - dLat).abs() < 0.001 && (w.lng - dLng).abs() < 0.001,
        );
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _busNameController.dispose();
    _busNumberController.dispose();
    _driverEmailController.dispose();
    _driverPasswordController.dispose();
    _salaryController.dispose();
    _receveurController.dispose();
    _lastVidangeKmController.dispose();
    _currentKmController.dispose();
    super.dispose();
  }

  // ============================================
  // PICK DOCUMENTS
  // ============================================
  Future<void> _pickImage(bool isLigne) async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Sélectionner une source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt),
              title: Text('Prendre une photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library),
              title: Text('Sélectionner depuis la galerie'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );
    if (file == null) return;
    setState(() {
      if (isLigne) {
        _ligneValidationFile = file;
      } else {
        _assuranceFile = file;
      }
    });
  }

  Future<void> _pickAssuranceExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _insuranceEndDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _insuranceEndDate = picked);
  }

  Future<void> _pickVidangeDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _lastVidangeDate ?? DateTime.now(),
      firstDate: DateTime(2010),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _lastVidangeDate = picked);
  }

  void _setTripsCount(int count) {
    if (count < 1) return;
    setState(() {
      _numberOfTrips = count;
      if (count > _tripSchedules.length) {
        _tripSchedules.addAll(List.filled(count - _tripSchedules.length, null));
      } else {
        _tripSchedules = _tripSchedules.sublist(0, count);
      }
    });
  }

  Future<void> _pickTripTime(int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _tripSchedules[index] ?? TimeOfDay.now(),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _tripSchedules[index] = picked);
  }

  String _tripTimeString(int index) {
    final t = _tripSchedules[index];
    if (t == null) return 'Non définie';
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  List<String> get _tripScheduleStrings =>
      _tripSchedules.map((t) {
        if (t == null) return '';
        return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
      }).where((s) => s.isNotEmpty).toList();

  // ============================================
  // UPLOAD DOCUMENTS TO STORAGE
  // ============================================

  /// Uploads a single file to Supabase Storage at [storagePath]
  /// and returns the public URL of the uploaded file.
  Future<String> _uploadFile(XFile file, String storagePath) async {
    debugPrint('[Upload] Starting: $storagePath');
    final bytes = await file.readAsBytes();
    debugPrint('[Upload] Read ${bytes.length} bytes');
    final url = await SupabaseStorageService.uploadFile(bytes, storagePath);
    debugPrint('[Upload] Done: $url');
    return url;
  }

  Future<Map<String, String>> _uploadDocuments(String busId) async {
    setState(() => _uploadingDocs = true);
    final results = <String, String>{};
    final ts = DateTime.now().millisecondsSinceEpoch;

    try {
      if (_ligneValidationFile != null) {
        results['ligneValidationUrl'] = await _uploadFile(
          _ligneValidationFile!,
          'buses/$busId/${ts}_ligne_validation.jpg',
        );
      }
      if (_assuranceFile != null) {
        results['assuranceUrl'] = await _uploadFile(
          _assuranceFile!,
          'buses/$busId/${ts}_assurance.jpg',
        );
      }
    } catch (e) {
      debugPrint('[Upload] Error: $e');
      rethrow;
    } finally {
      setState(() => _uploadingDocs = false);
    }

    return results;
  }

  // ============================================
  // SAVE
  // ============================================
  Future<void> _saveBus() async {
    if (!_formKey.currentState!.validate()) return;



    if (!_isEditing) {
      if (_ligneValidationFile == null) {
        _showError('La validation de ligne est requise');
        return;
      }
      if (_assuranceFile == null) {
        _showError('L\'assurance est requise');
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      if (_isEditing) {
        await _updateBus();
        if (mounted) {
          _showSuccess('Bus mis à jour avec succès !');
          Navigator.pop(context);
        }
      } else {
        await _createBusWithDriver();
        if (mounted) {
          _showSuccess(
              'Bus créé ! En attente de validation par l\'administrateur.\nChauffeur: ${_driverEmailController.text.trim()}');
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============================================
  // CREATE BUS + DRIVER
  // ============================================
  static const _planLimits = {'starter': 3, 'pro': 10};

  Future<void> _createBusWithDriver() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw 'Vous n\'êtes pas connecté.';
    final ownerUid = currentUser.uid;

    // Enforce subscription plan bus limit
    final userDoc = await _firestore.collection('users').doc(ownerUid).get();
    final plan = (userDoc.data()?['subscription'] as String? ?? 'starter').toLowerCase();
    final limit = _planLimits[plan]; // null = enterprise (unlimited)
    if (limit != null) {
      final countSnap = await _firestore
          .collection('buses')
          .where('ownerId', isEqualTo: ownerUid)
          .count()
          .get();
      final current = countSnap.count ?? 0;
      if (current >= limit) {
        final planName = plan[0].toUpperCase() + plan.substring(1);
        throw 'Limite atteinte : le forfait $planName permet $limit bus maximum. '
            'Passez à un forfait supérieur pour ajouter plus de bus.';
      }
    }

    FirebaseApp? tempApp;
    String driverUid;

    try {
      try {
        tempApp = Firebase.app('TempDriverCreator');
      } catch (_) {
        tempApp = await Firebase.initializeApp(
          name: 'TempDriverCreator',
          options: Firebase.app().options,
        );
      }

      final tempAuth = FirebaseAuth.instanceFor(app: tempApp);

      UserCredential driverCredential;
      try {
        driverCredential = await tempAuth.createUserWithEmailAndPassword(
          email: _driverEmailController.text.trim(),
          password: _driverPasswordController.text.trim(),
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          throw 'Cet email est déjà utilisé.';
        }
        if (e.code == 'weak-password') {
          throw 'Mot de passe trop faible.';
        }
        throw 'Erreur: ${e.message}';
      }

      driverUid = driverCredential.user!.uid;
      await tempAuth.signOut();
    } catch (e) {
      if (e is String) rethrow;
      throw 'Erreur création compte chauffeur: $e';
    }

    // Save driver in users collection
    await _firestore.collection('users').doc(driverUid).set({
      'uid': driverUid,
      'email': _driverEmailController.text.trim(),
      'role': 'driver',
      'displayName': _busNameController.text.trim(),
      'createdAt': Timestamp.now(),
    });

    // Generate busId before uploading so Storage path is known
    final busId = _uuid.v4();

    // Upload documents to Firebase Storage
    final docUrls = await _uploadDocuments(busId);

    // Vidange km
    final kmText = _lastVidangeKmController.text.trim();
    final vidangeKm = kmText.isNotEmpty ? int.tryParse(kmText) : null;

    // Current km
    final currKmText = _currentKmController.text.trim();
    final currentKm = currKmText.isNotEmpty ? int.tryParse(currKmText) : null;

    // Salary and receveur
    final salaryText = _salaryController.text.trim();
    final salary = salaryText.isNotEmpty ? int.tryParse(salaryText) : null;
    final receveurText = _receveurController.text.trim();
    final receveur = receveurText.isNotEmpty ? int.tryParse(receveurText) : null;

    // Create bus — inactive until admin approves
    await _firestore.collection('buses').doc(busId).set({
      'busId': busId,
      'busName': _busNameController.text.trim(),
      'busNumber': _busNumberController.text.trim(),
      'isActive': false,
      'createdAt': Timestamp.now(),
      'ownerId': ownerUid,
      'driverId': driverUid,
      'driverStatus': 'offline',
      'validationStatus': 'pending',
      'ligneValidationUrl': docUrls['ligneValidationUrl'],
      'assuranceUrl': docUrls['assuranceUrl'],
      'salary': salary,
      'recipient': receveur,
      'currentKm': currentKm,
      'assuranceEndDate':
          _insuranceEndDate != null ? Timestamp.fromDate(_insuranceEndDate!) : null,
      'lastVidangeDate':
          _lastVidangeDate != null ? Timestamp.fromDate(_lastVidangeDate!) : null,
      'lastVidangeKm': vidangeKm,
      'validationNote': null,
      'numberOfTrips': _numberOfTrips,
      'tripSchedules': _tripScheduleStrings,
      'chauffeurSalaryType': _chauffeurSalaryType,
      'receveurSalaryType': _receveurSalaryType,
      if (_selectedDepartureWilaya != null) ...{
        'departureLat': _selectedDepartureWilaya!.lat,
        'departureLng': _selectedDepartureWilaya!.lng,
      },
      if (_selectedArrivalWilaya != null) ...{
        'arrivalLat': _selectedArrivalWilaya!.lat,
        'arrivalLng': _selectedArrivalWilaya!.lng,
      },
    });
  }

  // ============================================
  // WILAYA PICKER
  // ============================================
  Future<void> _pickWilaya({required bool isDeparture}) async {
    final search = ValueNotifier('');
    final current = isDeparture ? _selectedDepartureWilaya : _selectedArrivalWilaya;
    final result = await showModalBottomSheet<Wilaya>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            Text(
              isDeparture ? 'Wilaya de départ' : 'Wilaya d\'arrivée',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Rechercher une wilaya...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) => search.value = v.toLowerCase(),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ValueListenableBuilder<String>(
                valueListenable: search,
                builder: (_, q, __) {
                  final filtered = kWilayas.where((w) => w.name.toLowerCase().contains(q)).toList();
                  return ListView.builder(
                    controller: controller,
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final w = filtered[i];
                      final selected = current?.code == w.code;
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: selected
                              ? Theme.of(ctx).colorScheme.primary
                              : Theme.of(ctx).colorScheme.surfaceContainerHighest,
                          child: Text('${w.code}',
                              style: TextStyle(
                                fontSize: 11,
                                color: selected ? Colors.white : Theme.of(ctx).colorScheme.onSurfaceVariant,
                              )),
                        ),
                        title: Text(w.name, style: const TextStyle(fontSize: 14)),
                        trailing: selected ? Icon(Icons.check, color: Theme.of(ctx).colorScheme.primary) : null,
                        onTap: () => Navigator.pop(ctx, w),
                      );
                    },
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
    if (result == null) return;
    setState(() {
      if (isDeparture) {
        _selectedDepartureWilaya = result;
      } else {
        _selectedArrivalWilaya = result;
      }
    });
  }

  Widget _wilayaPickerTile({required bool isDeparture}) {
    final selected = isDeparture ? _selectedDepartureWilaya : _selectedArrivalWilaya;
    final label    = isDeparture ? 'Wilaya de départ' : 'Wilaya d\'arrivée';
    final hint     = isDeparture ? 'Choisir la wilaya de départ' : 'Choisir la wilaya d\'arrivée';
    final icon     = isDeparture ? Icons.trip_origin : Icons.location_on;

    return InkWell(
      onTap: () => _pickWilaya(isDeparture: isDeparture),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected != null
              ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          border: Border.all(
            color: selected != null
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)
                : Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(children: [
          Icon(icon,
              color: selected != null
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(
                selected != null ? selected.name : hint,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected != null ? FontWeight.w600 : FontWeight.normal,
                  color: selected != null
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ]),
          ),
          Icon(Icons.arrow_drop_down, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ]),
      ),
    );
  }

  // ============================================
  // UPDATE BUS
  // ============================================
  Future<void> _updateBus() async {
    final currKmText = _currentKmController.text.trim();
    await _firestore.collection('buses').doc(widget.busToEdit!.busId).update({
      'busName': _busNameController.text.trim(),
      'busNumber': _busNumberController.text.trim(),
      'isActive': _isActive,
      if (currKmText.isNotEmpty) 'currentKm': int.parse(currKmText),
      'numberOfTrips': _numberOfTrips,
      'tripSchedules': _tripScheduleStrings,
      'chauffeurSalaryType': _chauffeurSalaryType,
      'receveurSalaryType': _receveurSalaryType,
    });
  }

  // ============================================
  // HELPERS
  // ============================================
  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ============================================
  // DOCUMENT PICKER WIDGET
  // ============================================
  Widget _documentPicker({
    required String label,
    required IconData icon,
    required Color color,
    required XFile? file,
    required VoidCallback onTap,
  }) {
    final hasFile = file != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: hasFile ? color.withValues(alpha: 0.05) : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: hasFile
                  ? color.withValues(alpha: 0.1)
                  : Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: hasFile ? color : Theme.of(context).colorScheme.onSurfaceVariant, size: 22),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: hasFile ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: 2),
              Text(
                hasFile ? file.name : 'Appuyez pour prendre une photo ou sélectionner depuis la galerie',
                style: TextStyle(
                  fontSize: 12,
                  color: hasFile ? color : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ]),
          ),
          SizedBox(width: 8),
          if (hasFile)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.file(
                File(file.path),
                width: 44, height: 44, fit: BoxFit.cover,
              ),
            )
          else
            Icon(Icons.add_photo_alternate_outlined,
                color: Theme.of(context).colorScheme.onSurfaceVariant, size: 26),
        ]),
      ),
    );
  }

  // ============================================
  // BUILD UI
  // ============================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifier le bus' : 'Ajouter un bus')
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Center(
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isEditing ? Icons.edit : Icons.add_circle_outline,
                    size: 40,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              SizedBox(height: 28),

              // ============================================
              // BUS INFO
              // ============================================
              _SectionTitle(title: 'Informations du bus', icon: Icons.directions_bus),
              SizedBox(height: 12),



              TextFormField(
                controller: _busNameController,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nom du bus *',
                  hintText: 'Ex: Bus A1',
                  prefixIcon: Icon(Icons.label_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Champ requis';
                  return null;
                },
              ),
              SizedBox(height: 16),

              TextFormField(
                controller: _busNumberController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Numéro du bus *',
                  hintText: 'Ex: 00125-114-16',
                  prefixIcon: Icon(Icons.confirmation_number_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Champ requis';
                  return null;
                },
              ),
              SizedBox(height: 16),

              // ── Nombre de trajets par jour ──
              _SectionTitle(title: 'Trajets journaliers', icon: Icons.repeat_rounded),
              SizedBox(height: 12),
              Row(
                children: [
                  IconButton.filled(
                    onPressed: () => _setTripsCount(_numberOfTrips - 1),
                    icon: const Icon(Icons.remove),
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        '$_numberOfTrips trajet${_numberOfTrips > 1 ? 's' : ''} / jour',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  IconButton.filled(
                    onPressed: () => _setTripsCount(_numberOfTrips + 1),
                    icon: const Icon(Icons.add),
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      foregroundColor: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              // ── Heure de départ pour chaque trajet ──
              ...List.generate(_numberOfTrips, (i) {
                final hasTime = _tripSchedules[i] != null;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () => _pickTripTime(i),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: hasTime
                            ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4)
                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                        border: Border.all(
                          color: hasTime
                              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)
                              : Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: Row(children: [
                        Icon(Icons.schedule_outlined,
                            color: hasTime
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                            size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Trajet ${i + 1} — ${_tripTimeString(i)}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: hasTime ? FontWeight.w600 : FontWeight.normal,
                              color: hasTime
                                  ? Theme.of(context).colorScheme.onSurface
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Icon(Icons.access_time,
                            size: 18,
                            color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ]),
                    ),
                  ),
                );
              }),
              SizedBox(height: 8),

              if (_isEditing) ...[
                Card(
                  child: SwitchListTile(
                    title: Text('Bus actif'),
                    subtitle: Text(
                      _isActive ? 'Le bus est en service' : 'Le bus est hors service',
                      style: TextStyle(color: _isActive ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.tertiary),
                    ),
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                    secondary: Icon(
                      _isActive ? Icons.check_circle : Icons.cancel,
                      color: _isActive ? Colors.green : Colors.orange,
                    ),
                  ),
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _currentKmController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Kilométrage actuel du bus',
                    hintText: 'Ex: 142000',
                    prefixIcon: Icon(Icons.speed_outlined),
                    suffixText: 'km',
                  ),
                ),
                SizedBox(height: 16),

              ],

              if (!_isEditing) ...[

                // ── Départ / Arrivée ──
                SizedBox(height: 24),
                _SectionTitle(
                  title: 'Trajet (premier départ)',
                  icon: Icons.route_outlined,
                  subtitle: 'Wilaya de départ et d\'arrivée du premier trajet',
                ),
                SizedBox(height: 12),
                _wilayaPickerTile(isDeparture: true),
                SizedBox(height: 10),
                _wilayaPickerTile(isDeparture: false),

                // ── Driver Account ──
                SizedBox(height: 24),
                _SectionTitle(
                  title: 'Compte chauffeur',
                  icon: Icons.person,
                  subtitle: 'Le chauffeur utilisera ces identifiants pour se connecter',
                ),
                SizedBox(height: 12),

                TextFormField(
                  controller: _driverEmailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email du chauffeur *',
                    hintText: 'Ex: chauffeur1@transport.com',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Champ requis';
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) {
                      return 'Email invalide';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),

                TextFormField(
                  controller: _driverPasswordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe du chauffeur *',
                    hintText: 'Minimum 6 caractères',
                    prefixIcon: Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Champ requis';
                    if (v.length < 6) return 'Minimum 6 caractères';
                    return null;
                  },
                ),
                SizedBox(height: 16),

                // ── Salaire chauffeur ──
                _SectionTitle(title: 'Salaire du chauffeur', icon: Icons.payments_outlined),
                SizedBox(height: 10),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'monthly', icon: Icon(Icons.calendar_month, size: 16), label: Text('Par mois')),
                    ButtonSegment(value: 'per_trip', icon: Icon(Icons.route, size: 16), label: Text('Par trajet')),
                  ],
                  selected: {_chauffeurSalaryType},
                  onSelectionChanged: (v) => setState(() => _chauffeurSalaryType = v.first),
                ),
                SizedBox(height: 10),
                TextFormField(
                  controller: _salaryController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: _chauffeurSalaryType == 'monthly'
                        ? 'Salaire du chauffeur (par mois) *'
                        : 'Salaire du chauffeur (par trajet) *',
                    hintText: 'Ex: 50000',
                    prefixIcon: const Icon(Icons.payments_outlined),
                    suffixText: 'DA',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Champ requis';
                    if (int.tryParse(v.trim()) == null) return 'Nombre invalide';
                    return null;
                  },
                ),
                SizedBox(height: 16),

                // ── Salaire receveur ──
                _SectionTitle(title: 'Part du receveur', icon: Icons.people_outlined),
                SizedBox(height: 10),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'monthly', icon: Icon(Icons.calendar_month, size: 16), label: Text('Par mois')),
                    ButtonSegment(value: 'per_trip', icon: Icon(Icons.route, size: 16), label: Text('Par trajet')),
                  ],
                  selected: {_receveurSalaryType},
                  onSelectionChanged: (v) => setState(() => _receveurSalaryType = v.first),
                ),
                SizedBox(height: 10),
                TextFormField(
                  controller: _receveurController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: _receveurSalaryType == 'monthly'
                        ? 'Part du receveur (par mois)'
                        : 'Part du receveur (par trajet)',
                    hintText: 'Ex: 15000',
                    prefixIcon: const Icon(Icons.people_outlined),
                    suffixText: 'DA',
                  ),
                ),
                SizedBox(height: 12),

                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(20),

                  ),
                  child: Row(children: [
                    Icon(Icons.info_outline, color: Theme.of(context).colorScheme.secondary, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Communiquez cet email et mot de passe au chauffeur.',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSecondaryContainer, fontSize: 12),
                      ),
                    ),
                  ]),
                ),

                // ── Documents obligatoires ──
                SizedBox(height: 24),
                _SectionTitle(
                  title: 'Documents obligatoires',
                  icon: Icons.folder_open,
                  subtitle: 'Ces documents seront vérifiés par l\'administrateur',
                ),
                SizedBox(height: 12),

                _documentPicker(
                  label: 'Validation de ligne',
                  icon: Icons.route,
                  color: Colors.indigo,
                  file: _ligneValidationFile,
                  onTap: () => _pickImage(true),
                ),
                SizedBox(height: 12),

                _documentPicker(
                  label: 'Assurance',
                  icon: Icons.shield_outlined,
                  color: Colors.teal,
                  file: _assuranceFile,
                  onTap: () => _pickImage(false),
                ),
                SizedBox(height: 12),

                InkWell(
                  onTap: _pickAssuranceExpiryDate,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: EdgeInsets.all(14),
                    decoration: BoxDecoration(

                      borderRadius: BorderRadius.circular(20),
                      color: _insuranceEndDate != null
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    child: Row(children: [
                      Icon(Icons.event_outlined,
                          color: _insuranceEndDate != null
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant),
                      SizedBox(width: 12),
                      Text(
                        _insuranceEndDate != null
                            ? 'Expiration assurance : ${DateFormat('dd/MM/yyyy').format(_insuranceEndDate!)}'
                            : 'Date d\'expiration de l\'assurance (optionnel)',
                        style: TextStyle(
                          color: _insuranceEndDate != null
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ]),
                  ),
                ),

                // ── Dernière vidange (optionnel) ──
                SizedBox(height: 24),
                _SectionTitle(
                  title: 'Dernière vidange (optionnel)',
                  icon: Icons.oil_barrel_outlined,
                ),
                SizedBox(height: 12),

                InkWell(
                  onTap: _pickVidangeDate,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: EdgeInsets.all(14),
                    decoration: BoxDecoration(

                      borderRadius: BorderRadius.circular(20),
                      color: _lastVidangeDate != null
                          ? Theme.of(context).colorScheme.tertiaryContainer
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    child: Row(children: [
                      Icon(Icons.calendar_today,
                          color: _lastVidangeDate != null
                              ? Theme.of(context).colorScheme.tertiary
                              : Theme.of(context).colorScheme.onSurfaceVariant),
                      SizedBox(width: 12),
                      Text(
                        _lastVidangeDate != null
                            ? DateFormat('dd/MM/yyyy').format(_lastVidangeDate!)
                            : 'Choisir la date de vidange',
                        style: TextStyle(
                          color: _lastVidangeDate != null
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ]),
                  ),
                ),
                SizedBox(height: 12),

                TextFormField(
                  controller: _lastVidangeKmController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Kilométrage à la vidange',
                    hintText: 'Ex: 125000',
                    prefixIcon: Icon(Icons.speed),
                    suffixText: 'km',
                  ),
                ),
                SizedBox(height: 12),
                TextFormField(
                  controller: _currentKmController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Kilométrage actuel du bus',
                    hintText: 'Ex: 142000',
                    prefixIcon: Icon(Icons.speed_outlined),
                    suffixText: 'km',
                  ),
                ),
              ],

              SizedBox(height: 32),

              // Save button
              ElevatedButton.icon(
                onPressed: (_isLoading || _uploadingDocs) ? null : _saveBus,
                icon: (_isLoading || _uploadingDocs)
                    ? SizedBox(
                        height: 20, width: 20,
                        child: BusLoadingIndicator(strokeWidth: 2))
                    : Icon(_isEditing ? Icons.save : Icons.add),
                label: Text(
                  _uploadingDocs
                      ? 'Upload en cours...'
                      : _isLoading
                          ? 'Création...'
                          : _isEditing
                              ? 'Enregistrer les modifications'
                              : 'Créer le bus et le compte chauffeur',
                  style: TextStyle(fontSize: 15),
                ),
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────


class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? subtitle;

  const _SectionTitle({required this.title, required this.icon, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            SizedBox(width: 8),
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        if (subtitle != null) ...[
          SizedBox(height: 4),
          Padding(
            padding: EdgeInsets.only(left: 28),
            child: Text(subtitle!,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
          ),
        ],
      ],
    );
  }
}
