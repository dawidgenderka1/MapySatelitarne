import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/satellite_map.dart';
import '../models/map_metadata.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Stream<List<SatelliteMap>> getMapsStream({bool publicOnly = false}) {
    Query query = _firestore.collection('satellite_maps');
    
    if (publicOnly) {
      query = query.where('isPublic', isEqualTo: true);
    }
    
    return query
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SatelliteMap.fromFirestore(doc))
            .toList());
  }

  Future<SatelliteMap?> getMap(String mapId) async {
    final doc = await _firestore.collection('satellite_maps').doc(mapId).get();
    if (doc.exists) {
      return SatelliteMap.fromFirestore(doc);
    }
    return null;
  }

  Future<String> addMap(SatelliteMap map) async {
    final docRef = await _firestore.collection('satellite_maps').add(map.toFirestore());
    return docRef.id;
  }

  Future<void> updateMetadata(String mapId, MapMetadata metadata) async {
    await _firestore.collection('satellite_maps').doc(mapId).update({
      'metadata': metadata.toMap(),
    });
  }

  Future<void> updateMetadataDescriptions(
    String mapId,
    Map<String, String> descriptions,
  ) async {
    await _firestore.collection('satellite_maps').doc(mapId).update({
      'metadataDescriptions': descriptions,
    });
  }

  Future<void> deleteMap(String mapId) async {
    await _firestore.collection('satellite_maps').doc(mapId).delete();
  }

  Future<void> incrementViewCount(String mapId) async {
    await _firestore.collection('satellite_maps').doc(mapId).update({
      'generatedMetadata.viewCount': FieldValue.increment(1),
      'generatedMetadata.lastViewed': FieldValue.serverTimestamp(),
    });
  }

  Future<List<SatelliteMap>> getMaps({bool publicOnly = false}) async {
    Query query = _firestore.collection('satellite_maps');
    
    if (publicOnly) {
      query = query.where('isPublic', isEqualTo: true);
    }
    
    final snapshot = await query.orderBy('uploadedAt', descending: true).get();
    return snapshot.docs.map((doc) => SatelliteMap.fromFirestore(doc)).toList();
  }
}