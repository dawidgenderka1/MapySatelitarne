import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firestore_service.dart';
import '../models/satellite_map.dart';
import 'auth_provider.dart';

final firestoreServiceProvider = Provider((ref) => FirestoreService());

final mapsStreamProvider = StreamProvider<List<SatelliteMap>>((ref) {
  final authState = ref.watch(authStateProvider);
  final isAnonymous = authState.value?.isAnonymous ?? true;
  
  return ref
      .watch(firestoreServiceProvider)
      .getMapsStream(publicOnly: isAnonymous);
});

final mapProvider = FutureProvider.family<SatelliteMap?, String>((ref, mapId) {
  return ref.watch(firestoreServiceProvider).getMap(mapId);
});

final mapsListProvider = FutureProvider<List<SatelliteMap>>((ref) async {
  final authState = ref.watch(authStateProvider);
  final isAnonymous = authState.value?.isAnonymous ?? true;
  
  return await ref
      .watch(firestoreServiceProvider)
      .getMaps(publicOnly: isAnonymous);
});