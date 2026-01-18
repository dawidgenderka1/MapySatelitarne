import 'package:cloud_firestore/cloud_firestore.dart';
import 'map_metadata.dart';

class SatelliteMap {
  final String id;
  final String fileName;
  final DateTime uploadedAt;
  final String uploadedBy;
  final String storageUrl;
  final String? thumbnailUrl;
  final bool isPublic;
  final MapMetadata metadata;
  final GeneratedMetadata generatedMetadata;
  final Map<String, String> metadataDescriptions;

  SatelliteMap({
    required this.id,
    required this.fileName,
    required this.uploadedAt,
    required this.uploadedBy,
    required this.storageUrl,
    this.thumbnailUrl,
    required this.isPublic,
    required this.metadata,
    required this.generatedMetadata,
    required this.metadataDescriptions,
  });

  factory SatelliteMap.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SatelliteMap(
      id: doc.id,
      fileName: data['fileName'] ?? '',
      uploadedAt: (data['uploadedAt'] as Timestamp).toDate(),
      uploadedBy: data['uploadedBy'] ?? '',
      storageUrl: data['storageUrl'] ?? '',
      thumbnailUrl: data['thumbnailUrl'],
      isPublic: data['isPublic'] ?? false,
      metadata: MapMetadata.fromMap(data['metadata'] ?? {}),
      generatedMetadata: GeneratedMetadata.fromMap(data['generatedMetadata'] ?? {}),
      metadataDescriptions: Map<String, String>.from(data['metadataDescriptions'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'fileName': fileName,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'uploadedBy': uploadedBy,
      'storageUrl': storageUrl,
      'thumbnailUrl': thumbnailUrl,
      'isPublic': isPublic,
      'metadata': metadata.toMap(),
      'generatedMetadata': generatedMetadata.toMap(),
      'metadataDescriptions': metadataDescriptions,
    };
  }
}