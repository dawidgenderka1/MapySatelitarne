import 'package:cloud_functions/cloud_functions.dart';

class CloudFunctionsService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<void> recordMapView(String mapId) async {
    try {
      final callable = _functions.httpsCallable('recordMapView');
      await callable.call({'mapId': mapId});
    } catch (e) {
      print('Błąd wywołania Cloud Function: $e');
      rethrow;
    }
  }
}
