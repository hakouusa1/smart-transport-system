import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../models/bus_model.dart';
import '../services/supabase_storage_service.dart';
import 'package:intl/intl.dart';
import '../theme_notifier.dart';
import '../widgets/bus_loading_indicator.dart';



class AssuranceDetailsScreen extends StatefulWidget {
  final Bus bus;

  const AssuranceDetailsScreen({super.key, required this.bus});

  @override
  State<AssuranceDetailsScreen> createState() => _AssuranceDetailsScreenState();
}

class _AssuranceDetailsScreenState extends State<AssuranceDetailsScreen> {
  bool _isLoading = false;
  DateTime? _selectedDate;
  Uint8List? _imageBytes;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.bus.insuranceEndDate;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: ColorScheme.light(primary: context.appPurple)),
        child: child!,
      ),
      locale: const Locale('fr', 'FR'),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickImage() async {
    try {
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

      final XFile? image = await _picker.pickImage(source: source, imageQuality: 70);
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() => _imageBytes = bytes);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  Future<void> _saveChanges() async {
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Veuillez sélectionner une date d\'expiration'), backgroundColor: context.appRed
      ));
      return;
    }

    setState(() => _isLoading = true);
    try {
      String? newUrl = widget.bus.assuranceUrl;

      // Upload if there's a new image
      if (_imageBytes != null) {
        final path = 'assurance_${widget.bus.busId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        newUrl = await SupabaseStorageService.uploadFile(_imageBytes!, path);
      }

      await FirebaseFirestore.instance.collection('buses').doc(widget.bus.busId).update({
        'assuranceEndDate': Timestamp.fromDate(_selectedDate!),
        if (_imageBytes != null) 'assuranceUrl': newUrl,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Assurance mise à jour avec succès'),
            backgroundColor: context.appGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            margin: EdgeInsets.all(16),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: context.appRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            margin: EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bus = widget.bus;
    
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: context.appBg,
        body: Column(
          children: [
            // ── Header ──
            Container(
              padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 24),
              decoration: BoxDecoration(
                
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: context.appPurple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(Icons.arrow_back, color: context.appDark),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Renouveler l\'Assurance',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: EdgeInsets.all(20),
                children: [
                  Text(
                    'Bus sélectionné: ${bus.busName.isNotEmpty ? bus.busName : bus.busNumber}',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.appDark),
                  ),
                  SizedBox(height: 24),

                  // Date Picker
                  Text('Nouvelle date d\'expiration', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.appDark)),
                  SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_month, color: context.appPurple),
                          SizedBox(width: 12),
                          Text(
                            _selectedDate != null 
                                ? DateFormat('dd MMMM yyyy', 'fr').format(_selectedDate!) 
                                : 'Sélectionner une date',
                            style: TextStyle(
                              fontSize: 15,
                              color: _selectedDate != null ? context.appDark : context.appSub,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 24),

                  // Image Picker
                  Text('Photo du document (Optionnel)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.appDark)),
                  SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        
                      ),
                      child: _imageBytes != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: context.appPurple.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.add_a_photo, color: context.appPurple, size: 28),
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Appuyez pour prendre une photo ou\nsélectionner depuis la galerie',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13, color: context.appSub),
                                ),
                              ],
                            ),
                    ),
                  ),

                  SizedBox(height: 48),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.appPurple,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isLoading
                          ? SizedBox(width: 24, height: 24, child: BusLoadingIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(
                              'Enregistrer',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
