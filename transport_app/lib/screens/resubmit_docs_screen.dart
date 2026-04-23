import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../models/bus_model.dart';
import '../services/supabase_storage_service.dart';
import '../theme_notifier.dart';
import '../widgets/bus_loading_indicator.dart';


class ResubmitDocsScreen extends StatefulWidget {
  final Bus bus;
  const ResubmitDocsScreen({super.key, required this.bus});

  @override
  State<ResubmitDocsScreen> createState() => _ResubmitDocsScreenState();
}

class _ResubmitDocsScreenState extends State<ResubmitDocsScreen> {
  XFile? _ligneFile;
  XFile? _assuranceFile;
  bool _uploading = false;

  bool get _ligneHasIssue => widget.bus.ligneValidationStatus == 'issue';
  bool get _assuranceHasIssue => widget.bus.assuranceStatus == 'issue';

  // Submit is enabled only when every problematic doc has a new file selected
  bool get _canSubmit {
    if (_ligneHasIssue && _ligneFile == null) return false;
    if (_assuranceHasIssue && _assuranceFile == null) return false;
    return _ligneFile != null || _assuranceFile != null;
  }

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

    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );
    if (file == null) return;
    setState(() {
      if (isLigne) {
        _ligneFile = file;
      } else {
        _assuranceFile = file;
      }
    });
  }

  Future<void> _submit() async {
    setState(() => _uploading = true);
    try {
      final bus = widget.bus;
      final ts  = DateTime.now().millisecondsSinceEpoch;
      final updates = <String, dynamic>{
        // Bus goes back to pending so admin sees it again
        'validationStatus': 'pending',
      };

      if (_ligneFile != null) {
        final bytes = await _ligneFile!.readAsBytes();
        final url = await SupabaseStorageService.uploadFile(
          bytes, 'buses/${bus.busId}/${ts}_ligne_validation.jpg');
        updates['ligneValidationUrl']    = url;
        updates['ligneValidationStatus'] = 'pending';
        updates['ligneValidationNote']   = '';
      }

      if (_assuranceFile != null) {
        final bytes = await _assuranceFile!.readAsBytes();
        final url = await SupabaseStorageService.uploadFile(
          bytes, 'buses/${bus.busId}/${ts}_assurance.jpg');
        updates['assuranceUrl']    = url;
        updates['assuranceStatus'] = 'pending';
        updates['assuranceNote']   = '';
      }

      await FirebaseFirestore.instance
          .collection('buses')
          .doc(bus.busId)
          .update(updates);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Documents renvoyés — en attente de validation.'),
        backgroundColor: Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
      ));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur : $e'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bus = widget.bus;

    return Scaffold(
      appBar: AppBar(
        title: Text('Corriger les documents'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Info banner
          Container(
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(20),
              
            ),
            child: Row(children: [
              Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Re-soumettez uniquement les documents marqués avec un problème. '
                  'Votre bus sera remis en attente de validation.',
                  style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
                ),
              ),
            ]),
          ),
          SizedBox(height: 20),

          // Bus identity
          Text(
            bus.busName.isNotEmpty ? bus.busName : 'Bus',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E)),
          ),
          Text('N° ${bus.busNumber}',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          SizedBox(height: 24),

          // Ligne validation
          if (_ligneHasIssue) ...[
            _DocUploadTile(
              label: 'Validation de ligne',
              icon: Icons.route,
              color: Colors.indigo,
              issueNote: bus.ligneValidationNote,
              file: _ligneFile,
              onPick: () => _pickImage(true),
            ),
            SizedBox(height: 16),
          ],

          // Assurance
          if (_assuranceHasIssue) ...[
            _DocUploadTile(
              label: 'Assurance',
              icon: Icons.shield_outlined,
              color: Colors.teal,
              issueNote: bus.assuranceNote,
              file: _assuranceFile,
              onPick: () => _pickImage(false),
            ),
            SizedBox(height: 16),
          ],

          SizedBox(height: 12),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_canSubmit && !_uploading) ? _submit : null,
              icon: _uploading
                  ? SizedBox(width: 20, height: 20,
                      child: BusLoadingIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(Icons.send_rounded),
              label: Text(_uploading ? 'Envoi en cours...' : 'Envoyer les documents corrigés'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                padding: EdgeInsets.symmetric(vertical: 14),
                textStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Document upload tile: shows the issue note + file picker
// ─────────────────────────────────────────────────────────────────────────────
class _DocUploadTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final String? issueNote;
  final XFile? file;
  final VoidCallback onPick;

  const _DocUploadTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.issueNote,
    required this.file,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Issue description from admin
      if (issueNote != null && issueNote!.isNotEmpty)
        Container(
          margin: EdgeInsets.only(bottom: 10),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(20),
            
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.error_outline, color: Colors.red.shade700, size: 16),
            SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label,
                    style: TextStyle(fontWeight: FontWeight.w700,
                        fontSize: 13, color: Colors.red.shade800)),
                SizedBox(height: 3),
                Text(issueNote!,
                    style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
              ]),
            ),
          ]),
        ),

      // File picker
      InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: file != null ? color.withValues(alpha: 0.05) : Colors.grey.shade50,
          ),
          child: Row(children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: file != null
                    ? color.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: file != null ? color : Colors.grey, size: 22),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label,
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14,
                        color: file != null ? Colors.black87 : Colors.grey.shade600)),
                SizedBox(height: 2),
                Text(
                  file != null ? file!.name : 'Appuyez pour prendre une photo ou sélectionner depuis la galerie',
                  style: TextStyle(
                      fontSize: 12,
                      color: file != null ? color : Colors.grey.shade500),
                  overflow: TextOverflow.ellipsis,
                ),
              ]),
            ),
            SizedBox(width: 8),
            if (file != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.file(File(file!.path),
                    width: 44, height: 44, fit: BoxFit.cover),
              )
            else
              Icon(Icons.add_photo_alternate_outlined,
                  color: Colors.grey.shade400, size: 26),
          ]),
        ),
      ),
    ]);
  }
}
