import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_config.dart' as config;

/// Handles all file uploads to Supabase Storage.
/// Firebase remains for Auth, Firestore, and everything else.
class SupabaseStorageService {
  static const String supabaseUrl = config.supabaseUrl;
  static const String supabaseAnonKey = config.supabaseAnonKey;

  /// Name of the Supabase Storage bucket.
  /// Create this bucket in your Supabase dashboard (Storage → New bucket).
  /// Set it to **public** so the URLs are directly accessible.
  static const String _bucket = 'bus-documents';

  /// Uploads [bytes] to [storagePath] inside the bucket and returns the
  /// public URL of the uploaded file.
  static Future<String> uploadFile(
    Uint8List bytes,
    String storagePath,
  ) async {
    final storage = Supabase.instance.client.storage;

    await storage.from(_bucket).uploadBinary(
      storagePath,
      bytes,
      fileOptions: const FileOptions(
        contentType: 'image/jpeg',
        upsert: true,
      ),
    );

    return storage.from(_bucket).getPublicUrl(storagePath);
  }
}
