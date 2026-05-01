import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../data/wilayas_data.dart';
import '../l10n/app_localizations.dart';
import '../models/bus_model.dart';
import '../services/supabase_storage_service.dart';
import '../services/firebase_service.dart';
import '../theme_notifier.dart';
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
  final TextEditingController _poidsController = TextEditingController();
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
  bool _isReassigning = false;
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
    _salaryController = TextEditingController(
      text: widget.busToEdit?.salary != null
          ? widget.busToEdit!.salary!.toInt().toString()
          : '',
    );
    if (widget.busToEdit?.recipientSalary != null) {
      _receveurController.text = widget.busToEdit!.recipientSalary!.toInt().toString();
    }
    _isActive = widget.busToEdit?.isActive ?? true;
    if (widget.busToEdit?.currentKm != null) {
      _currentKmController.text = widget.busToEdit!.currentKm.toString();
    }
    if (widget.busToEdit?.weightKg != null) {
      _poidsController.text = widget.busToEdit!.weightKg.toString();
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
    final aLat = widget.busToEdit?.arrivalLat;
    final aLng = widget.busToEdit?.arrivalLng;
    if (aLat != null && aLng != null) {
      try {
        _selectedArrivalWilaya = kWilayas.firstWhere(
          (w) => (w.lat - aLat).abs() < 0.001 && (w.lng - aLng).abs() < 0.001,
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
    _poidsController.dispose();
    super.dispose();
  }

  // ============================================
  // PICK DOCUMENTS
  // ============================================
  Future<void> _pickImage(bool isLigne) async {
    final l10n = AppLocalizations.of(context);
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.selectSourceTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(l10n.takePhotoOption),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(l10n.selectFromGalleryOption),
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

  String _tripTimeString(int index, AppLocalizations l10n) {
    final t = _tripSchedules[index];
    if (t == null) return l10n.tripTimeNotSet;
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

    // Capture l10n before any async gap
    final l10n = AppLocalizations.of(context);

    if (_tripScheduleStrings.isEmpty) {
      _showError(l10n.errorAtLeastOneTripSchedule);
      return;
    }

    if (!_isEditing) {
      if (_ligneValidationFile == null) {
        _showError(l10n.errorLineValidationRequired);
        return;
      }
      if (_assuranceFile == null) {
        _showError(l10n.errorInsuranceRequired);
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      if (_isEditing) {
        await _updateBus();
        if (mounted) {
          _showSuccess(l10n.successBusUpdated);
          Navigator.pop(context);
        }
      } else {
        final busName = _busNameController.text.trim();
        final driverEmail = _driverEmailController.text.trim();
        final driverPassword = _driverPasswordController.text.trim();
        await _createBusWithDriver(l10n);
        if (mounted) {
          setState(() => _isLoading = false);
          await _showCredentialDialog(
            busName: busName,
            driverEmail: driverEmail,
            tempPassword: driverPassword,
          );
          if (mounted) Navigator.pop(context);
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

  Future<void> _createBusWithDriver(AppLocalizations l10n) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw l10n.errorNotLoggedIn;
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
        throw l10n.errorBusLimitFmt(planName, limit);
      }
    }

    FirebaseApp? tempApp;
    FirebaseAuth? tempAuth;
    String? driverUid;
    User? createdAuthUser;

    try {
      try {
        tempApp = Firebase.app('TempDriverCreator');
      } catch (_) {
        tempApp = await Firebase.initializeApp(
          name: 'TempDriverCreator',
          options: Firebase.app().options,
        );
      }

      tempAuth = FirebaseAuth.instanceFor(app: tempApp);

      try {
        final driverCredential = await tempAuth.createUserWithEmailAndPassword(
          email: _driverEmailController.text.trim(),
          password: _driverPasswordController.text.trim(),
        );
        createdAuthUser = driverCredential.user;
        driverUid = createdAuthUser!.uid;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') throw l10n.errorEmailAlreadyInUse;
        if (e.code == 'weak-password') throw l10n.errorWeakPassword;
        throw l10n.errorFmt(e.message ?? '');
      }

      // Save driver in users collection
      await _firestore.collection('users').doc(driverUid).set({
        'uid': driverUid,
        'email': _driverEmailController.text.trim(),
        'role': 'driver',
        'displayName': _busNameController.text.trim(),
        'createdAt': Timestamp.now(),
        'ownerId': ownerUid,
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
      final poidsText = _poidsController.text.trim();
      final poids = poidsText.isNotEmpty ? int.tryParse(poidsText) : null;

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
        'poids': poids,
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

      // Log bus creation (password is intentionally excluded)
      await _firestore.collection('bus_creation_logs').add({
        'email': _driverEmailController.text.trim(),
        'busId': busId,
        'busName': _busNameController.text.trim(),
        'adminUid': ownerUid,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Clean up orphaned driver account if auth was created but a later step failed
      if (createdAuthUser != null) {
        try {
          await createdAuthUser.delete();
          await _firestore.collection('users').doc(createdAuthUser.uid).delete();
        } catch (_) {}
      }
      if (e is String) rethrow;
      throw l10n.errorBusCreationFmt('$e');
    } finally {
      try { await tempAuth?.signOut(); } catch (_) {}
    }
  }

  // ============================================
  // WILAYA PICKER
  // ============================================
  Future<void> _pickWilaya({required bool isDeparture}) async {
    final l10n = AppLocalizations.of(context);
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
                decoration: BoxDecoration(color: ctx.appSub.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            Text(
              isDeparture ? l10n.departureWilaya : l10n.arrivalWilaya,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: l10n.searchWilayaHint,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
                              ? ctx.appPrimary
                              : ctx.appCardBg2,
                          child: Text('${w.code}',
                              style: TextStyle(
                                fontSize: 11,
                                color: selected ? Colors.white : ctx.appSub,
                              )),
                        ),
                        title: Text(w.name, style: const TextStyle(fontSize: 14)),
                        trailing: selected ? Icon(Icons.check, color: ctx.appPrimary) : null,
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
    final l10n = AppLocalizations.of(context);
    final selected = isDeparture ? _selectedDepartureWilaya : _selectedArrivalWilaya;
    final label    = isDeparture ? l10n.departureWilaya : l10n.arrivalWilaya;
    final hint     = isDeparture ? l10n.chooseDepartureWilaya : l10n.chooseArrivalWilaya;
    final icon     = isDeparture ? Icons.trip_origin : Icons.location_on;

    return InkWell(
      onTap: () => _pickWilaya(isDeparture: isDeparture),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected != null
              ? context.appPrimary.withValues(alpha: 0.1)
              : context.appCardBg2,
          border: Border.all(
            color: selected != null
                ? context.appPrimary.withValues(alpha: 0.4)
                : context.appBorder,
          ),
        ),
        child: Row(children: [
          Icon(icon,
              color: selected != null
                  ? context.appPrimary
                  : context.appSub,
              size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: TextStyle(fontSize: 12, color: context.appSub)),
              const SizedBox(height: 2),
              Text(
                selected != null ? selected.name : hint,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected != null ? FontWeight.w600 : FontWeight.normal,
                  color: selected != null
                      ? context.appText
                      : context.appSub,
                ),
              ),
            ]),
          ),
          Icon(Icons.arrow_drop_down, color: context.appSub),
        ]),
      ),
    );
  }

  // ============================================
  // UPDATE BUS
  // ============================================
  Future<void> _updateBus() async {
    final currKmText  = _currentKmController.text.trim();
    final poidsText   = _poidsController.text.trim();
    final salaryText  = _salaryController.text.trim();
    final receveurText = _receveurController.text.trim();
    await _firestore.collection('buses').doc(widget.busToEdit!.busId).update({
      'busName': _busNameController.text.trim(),
      'busNumber': _busNumberController.text.trim(),
      'isActive': _isActive,
      if (currKmText.isNotEmpty) 'currentKm': int.parse(currKmText),
      if (poidsText.isNotEmpty) 'poids': int.parse(poidsText),
      if (salaryText.isNotEmpty) 'salary': int.parse(salaryText),
      if (receveurText.isNotEmpty) 'recipient': int.parse(receveurText),
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
  // REASSIGN DRIVER
  // ============================================
  Future<void> _handleReassignDriver() async {
    final l10n = AppLocalizations.of(context);
    final email = _driverEmailController.text.trim();
    final password = _driverPasswordController.text.trim();

    if (email.isEmpty) {
      _showError(l10n.fieldRequired);
      return;
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _showError(l10n.invalidEmail);
      return;
    }
    if (password.isEmpty) {
      _showError(l10n.fieldRequired);
      return;
    }
    if (password.length < 6) {
      _showError(l10n.minSixChars);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.reassignConfirmTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
        content: Text(l10n.reassignConfirmMessage),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: context.appPurple),
            child: Text(l10n.confirmDialogTitle),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isReassigning = true);

    try {
      await FirebaseService().reassignDriver(
        busId: widget.busToEdit!.busId,
        newEmail: email,
        newPassword: password,
      );

      if (mounted) {
        _showSuccess(l10n.successCredentialsUpdated);
        // Clear fields after success
        _driverEmailController.clear();
        _driverPasswordController.clear();
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isReassigning = false);
    }
  }

  // ============================================
  // HELPERS
  // ============================================
  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: context.appRed,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: context.appPrimary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _showCredentialDialog({
    required String busName,
    required String driverEmail,
    required String tempPassword,
  }) async {
    final l10n = AppLocalizations.of(context);
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SuccessDialog(
        busName: busName,
        driverEmail: driverEmail,
        tempPassword: tempPassword,
        l10n: l10n,
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
    final l10n = AppLocalizations.of(context);
    final hasFile = file != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: hasFile ? color.withValues(alpha: 0.05) : context.appCardBg2,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: hasFile
                  ? color.withValues(alpha: 0.1)
                  : context.appCardBg2,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: hasFile ? color : context.appSub, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: hasFile ? context.appText : context.appSub,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                hasFile ? file.name : l10n.documentPickerHint,
                style: TextStyle(
                  fontSize: 12,
                  color: hasFile ? color : context.appSub,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ]),
          ),
          const SizedBox(width: 8),
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
                color: context.appSub, size: 26),
        ]),
      ),
    );
  }

  // ============================================
  // BUILD UI
  // ============================================
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.editBus : l10n.addBus),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.appPrimary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isEditing ? Icons.edit : Icons.add_circle_outline,
                    size: 40,
                    color: context.appPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // ============================================
              // BUS INFO
              // ============================================
              _SectionTitle(title: l10n.busInfoSection, icon: Icons.directions_bus),
              const SizedBox(height: 12),

              TextFormField(
                controller: _busNameController,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: '${l10n.busName} *',
                  hintText: l10n.busNameHint,
                  prefixIcon: const Icon(Icons.label_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return l10n.fieldRequired;
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _busNumberController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: '${l10n.busNumber} *',
                  hintText: l10n.busNumberHint,
                  prefixIcon: const Icon(Icons.confirmation_number_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return l10n.fieldRequired;
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ── Nombre de trajets par jour ──
              _SectionTitle(title: l10n.dailyTripsSection, icon: Icons.repeat_rounded),
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton.filled(
                    onPressed: () => _setTripsCount(_numberOfTrips - 1),
                    icon: const Icon(Icons.remove),
                    style: IconButton.styleFrom(
                      backgroundColor: context.appCardBg2,
                      foregroundColor: context.appText,
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        l10n.tripsPerDayFmt(_numberOfTrips),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  IconButton.filled(
                    onPressed: () => _setTripsCount(_numberOfTrips + 1),
                    icon: const Icon(Icons.add),
                    style: IconButton.styleFrom(
                      backgroundColor: context.appPrimary.withValues(alpha: 0.12),
                      foregroundColor: context.appPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
                            ? context.appPrimary.withValues(alpha: 0.1)
                            : context.appCardBg2,
                        border: Border.all(
                          color: hasTime
                              ? context.appPrimary.withValues(alpha: 0.4)
                              : context.appBorder,
                        ),
                      ),
                      child: Row(children: [
                        Icon(Icons.schedule_outlined,
                            color: hasTime
                                ? context.appPrimary
                                : context.appSub,
                            size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.tripScheduleRowFmt(i + 1, _tripTimeString(i, l10n)),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: hasTime ? FontWeight.w600 : FontWeight.normal,
                              color: hasTime
                                  ? context.appText
                                  : context.appSub,
                            ),
                          ),
                        ),
                        Icon(Icons.access_time,
                            size: 18,
                            color: context.appSub),
                      ]),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),

              if (_isEditing) ...[
                Card(
                  child: SwitchListTile(
                    title: Text(l10n.busActiveSwitchTitle),
                    subtitle: Text(
                      _isActive ? l10n.busActiveSubtitle : l10n.busInactiveSubtitle,
                      style: TextStyle(color: _isActive ? context.appPrimary : context.appOrange),
                    ),
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                    secondary: Icon(
                      _isActive ? Icons.check_circle : Icons.cancel,
                      color: _isActive ? context.appGreen : context.appOrange,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _currentKmController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.currentKmLabel,
                    hintText: l10n.currentKmHint,
                    prefixIcon: const Icon(Icons.speed_outlined),
                    suffixText: 'km',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _poidsController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.busWeightLabel,
                    hintText: l10n.busWeightHint,
                    prefixIcon: const Icon(Icons.fitness_center_outlined),
                    suffixText: 'kg',
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (_isEditing) ...[
                const SizedBox(height: 24),
                _SectionTitle(
                  title: l10n.ownerManagementSection,
                  icon: Icons.admin_panel_settings_outlined,
                  subtitle: l10n.ownerManagementSubtitle,
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  color: context.appPurple.withValues(alpha: 0.05),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: context.appPurple.withValues(alpha: 0.2)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _driverEmailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: l10n.driverEmailFieldLabel,
                            prefixIcon: const Icon(Icons.email_outlined),
                            filled: true,
                            fillColor: context.appBg,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _driverPasswordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: l10n.driverPasswordFieldLabel,
                            prefixIcon: const Icon(Icons.lock_outlined),
                            filled: true,
                            fillColor: context.appBg,
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _isReassigning ? null : _handleReassignDriver,
                            style: FilledButton.styleFrom(
                              backgroundColor: context.appPurple,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: _isReassigning
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.sync_alt, size: 20),
                            label: Text(l10n.updateCredentialsButton),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Départ / Arrivée ──
              const SizedBox(height: 24),
              _SectionTitle(
                title: l10n.routeSectionTitle,
                icon: Icons.route_outlined,
                subtitle: l10n.routeSectionSubtitle,
              ),
              const SizedBox(height: 12),
              _wilayaPickerTile(isDeparture: true),
              const SizedBox(height: 10),
              _wilayaPickerTile(isDeparture: false),

              if (!_isEditing) ...[

                // ── Driver Account ──
                const SizedBox(height: 24),
                _SectionTitle(
                  title: l10n.driverAccountSection,
                  icon: Icons.person,
                  subtitle: l10n.driverAccountSubtitle,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _driverEmailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: l10n.driverEmailFieldLabel,
                    hintText: l10n.driverEmailHint,
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return l10n.fieldRequired;
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) {
                      return l10n.invalidEmail;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _driverPasswordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: l10n.driverPasswordFieldLabel,
                    hintText: l10n.minSixChars,
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return l10n.fieldRequired;
                    if (v.length < 6) return l10n.minSixChars;
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],

              // ── Salaire chauffeur ── (create & edit)
              const SizedBox(height: 24),
              _SectionTitle(title: l10n.driverSalarySection, icon: Icons.payments_outlined),
              const SizedBox(height: 10),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'monthly', icon: const Icon(Icons.calendar_month, size: 16), label: Text(l10n.perMonthLabel)),
                  ButtonSegment(value: 'per_trip', icon: const Icon(Icons.route, size: 16), label: Text(l10n.perTripLabel)),
                ],
                selected: {_chauffeurSalaryType},
                onSelectionChanged: (v) => setState(() => _chauffeurSalaryType = v.first),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _salaryController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: _chauffeurSalaryType == 'monthly'
                      ? l10n.chauffeurSalaryMonthlyFieldLabel
                      : l10n.chauffeurSalaryPerTripFieldLabel,
                  hintText: l10n.salaryHint,
                  prefixIcon: const Icon(Icons.payments_outlined),
                  suffixText: 'DA',
                ),
                validator: (v) {
                  if (v != null && v.trim().isNotEmpty && int.tryParse(v.trim()) == null) {
                    return l10n.invalidNumber;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ── Salaire receveur ── (create & edit)
              _SectionTitle(title: l10n.collectorShareSection, icon: Icons.people_outlined),
              const SizedBox(height: 10),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'monthly', icon: const Icon(Icons.calendar_month, size: 16), label: Text(l10n.perMonthLabel)),
                  ButtonSegment(value: 'per_trip', icon: const Icon(Icons.route, size: 16), label: Text(l10n.perTripLabel)),
                ],
                selected: {_receveurSalaryType},
                onSelectionChanged: (v) => setState(() => _receveurSalaryType = v.first),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _receveurController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: _receveurSalaryType == 'monthly'
                      ? l10n.collectorShareMonthlyLabel
                      : l10n.collectorSharePerTripLabel,
                  hintText: l10n.collectorShareHint,
                  prefixIcon: const Icon(Icons.people_outlined),
                  suffixText: 'DA',
                ),
              ),

              if (!_isEditing) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.appPurple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(children: [
                    Icon(Icons.info_outline, color: context.appPurple, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.shareCredentialsWithDriver,
                        style: TextStyle(color: context.appText, fontSize: 12),
                      ),
                    ),
                  ]),
                ),

                // ── Documents obligatoires ──
                const SizedBox(height: 24),
                _SectionTitle(
                  title: l10n.requiredDocsSection,
                  icon: Icons.folder_open,
                  subtitle: l10n.requiredDocsSectionSubtitle,
                ),
                const SizedBox(height: 12),

                _documentPicker(
                  label: l10n.lineValidation,
                  icon: Icons.route,
                  color: context.appPrimary,
                  file: _ligneValidationFile,
                  onTap: () => _pickImage(true),
                ),
                const SizedBox(height: 12),

                _documentPicker(
                  label: l10n.insurance,
                  icon: Icons.shield_outlined,
                  color: context.appAccent,
                  file: _assuranceFile,
                  onTap: () => _pickImage(false),
                ),
                const SizedBox(height: 12),

                InkWell(
                  onTap: _pickAssuranceExpiryDate,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: _insuranceEndDate != null
                          ? context.appPrimary.withValues(alpha: 0.12)
                          : context.appCardBg2,
                    ),
                    child: Row(children: [
                      Icon(Icons.event_outlined,
                          color: _insuranceEndDate != null
                              ? context.appPrimary
                              : context.appSub),
                      const SizedBox(width: 12),
                      Text(
                        _insuranceEndDate != null
                            ? l10n.insuranceExpirySelectedFmt(DateFormat('dd/MM/yyyy').format(_insuranceEndDate!))
                            : l10n.insuranceExpiryOptional,
                        style: TextStyle(
                          color: _insuranceEndDate != null
                              ? context.appText
                              : context.appSub,
                        ),
                      ),
                    ]),
                  ),
                ),

                // ── Dernière vidange (optionnel) ──
                const SizedBox(height: 24),
                _SectionTitle(
                  title: l10n.lastOilChangeSectionTitle,
                  icon: Icons.oil_barrel_outlined,
                ),
                const SizedBox(height: 12),

                InkWell(
                  onTap: _pickVidangeDate,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: _lastVidangeDate != null
                          ? context.appAccent.withValues(alpha: 0.12)
                          : context.appCardBg2,
                    ),
                    child: Row(children: [
                      Icon(Icons.calendar_today,
                          color: _lastVidangeDate != null
                              ? context.appAccent
                              : context.appSub),
                      const SizedBox(width: 12),
                      Text(
                        _lastVidangeDate != null
                            ? DateFormat('dd/MM/yyyy').format(_lastVidangeDate!)
                            : l10n.oilChangeDateHint,
                        style: TextStyle(
                          color: _lastVidangeDate != null
                              ? context.appText
                              : context.appSub,
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _lastVidangeKmController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.oilChangeKmLabel,
                    hintText: l10n.oilChangeKmHint,
                    prefixIcon: const Icon(Icons.speed),
                    suffixText: 'km',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _currentKmController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.currentKmLabel,
                    hintText: l10n.currentKmHint,
                    prefixIcon: const Icon(Icons.speed_outlined),
                    suffixText: 'km',
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Save button
              ElevatedButton.icon(
                onPressed: (_isLoading || _uploadingDocs) ? null : _saveBus,
                icon: (_isLoading || _uploadingDocs)
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: BusLoadingIndicator(strokeWidth: 2))
                    : Icon(_isEditing ? Icons.save : Icons.add),
                label: Text(
                  _uploadingDocs
                      ? l10n.uploadingLabel
                      : _isLoading
                          ? l10n.creatingBusLabel
                          : _isEditing
                              ? l10n.saveChangesButton
                              : l10n.createBusAndDriverButton,
                  style: const TextStyle(fontSize: 15),
                ),
              ),
              const SizedBox(height: 20),
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
            Icon(icon, size: 20, color: context.appPrimary),
            const SizedBox(width: 8),
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Padding(
            // EdgeInsetsDirectional so start = right in RTL
            padding: const EdgeInsetsDirectional.only(start: 28),
            child: Text(subtitle!,
                style: TextStyle(color: context.appSub, fontSize: 12)),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────

class _SuccessDialog extends StatelessWidget {
  final String busName;
  final String driverEmail;
  final String tempPassword;
  final AppLocalizations l10n;

  const _SuccessDialog({
    required this.busName,
    required this.driverEmail,
    required this.tempPassword,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Success icon ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.appPrimary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_outline_rounded,
                  size: 48,
                  color: context.appPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // ── Title ──
              Text(
                l10n.busCreatedSuccess,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.busCreatedDialogSubtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: context.appSub,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // ── Credential card ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.appCardBg2,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.appBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CredentialRow(
                      icon: Icons.directions_bus_outlined,
                      label: l10n.busIdDialogLabel,
                      value: busName,
                    ),
                    const SizedBox(height: 14),
                    _CredentialRow(
                      icon: Icons.email_outlined,
                      label: l10n.driverEmailDialogLabel,
                      value: driverEmail,
                    ),
                    const SizedBox(height: 14),
                    _CredentialRow(
                      icon: Icons.lock_outlined,
                      label: l10n.temporaryPasswordLabel,
                      value: tempPassword,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Copy button ──
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    final text =
                        '${l10n.busIdDialogLabel}: $busName\n'
                        '${l10n.driverEmailDialogLabel}: $driverEmail\n'
                        '${l10n.temporaryPasswordLabel}: $tempPassword';
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.credentialsCopied),
                        backgroundColor: context.appPrimary,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: context.appPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.copy_rounded, size: 20),
                  label: Text(
                    l10n.copyCredentials,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // ── Close button ──
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    side: BorderSide(color: context.appBorder),
                  ),
                  child: Text(
                    l10n.closeLabel,
                    style: TextStyle(
                      fontSize: 15,
                      color: context.appText,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CredentialRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _CredentialRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: context.appSub),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: context.appSub,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              SelectableText(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.appText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
