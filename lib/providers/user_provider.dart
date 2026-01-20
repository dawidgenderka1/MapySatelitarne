import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';
import '../services/cloud_functions_service.dart';

final storageServiceProvider = Provider((ref) => StorageService());

final cloudFunctionsServiceProvider = Provider((ref) => CloudFunctionsService());