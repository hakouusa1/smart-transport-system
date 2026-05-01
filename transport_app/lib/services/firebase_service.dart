import 'package:cloud_functions/cloud_functions.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Calls the 'reassignDriver' Cloud Function.
  /// 
  /// [busId]: The ID of the bus to reassign.
  /// [newEmail]: The new driver email.
  /// [newPassword]: The new driver password.
  Future<void> reassignDriver({
    required String busId,
    required String newEmail,
    required String newPassword,
  }) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('reassignDriver');
      
      await callable.call(<String, dynamic>{
        'busId': busId,
        'newEmail': newEmail.trim(),
        'newPassword': newPassword.trim(),
      });
    } on FirebaseFunctionsException catch (e) {
      throw e.message ?? 'Une erreur est survenue lors de la réattribution.';
    } catch (e) {
      throw 'Erreur inattendue: $e';
    }
  }
}
