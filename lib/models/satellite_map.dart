import 'package:cloud_firestore/cloud_firestore.dart';
import 'map_metadata.dart';

class SatelliteMap {
  final String id;
  final String fileName;
  final DateTime uploadedAt;
  final String uploadedBy;
  final String storageUrl;
  final bool isPublic;
  final MapMetadata metadata;
  final GeneratedMetadata generatedMetadata;
  final Map<String, String> metadataDescriptions;

  final Map<String, dynamic> extraMetadata;

  SatelliteMap({
    required this.id,
    required this.fileName,
    required this.uploadedAt,
    required this.uploadedBy,
    required this.storageUrl,
    required this.isPublic,
    required this.metadata,
    required this.generatedMetadata,
    required this.metadataDescriptions,

    this.extraMetadata = const {},
  });

  factory SatelliteMap.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SatelliteMap(
      id: doc.id,
      fileName: data['fileName'] ?? '',
      uploadedAt: (data['uploadedAt'] as Timestamp).toDate(),
      uploadedBy: data['uploadedBy'] ?? '',
      storageUrl: data['storageUrl'] ?? '',
      isPublic: data['isPublic'] ?? false,
      metadata: MapMetadata.fromMap(data['metadata'] ?? {}),
      generatedMetadata: GeneratedMetadata.fromMap(data['generatedMetadata'] ?? {}),
      metadataDescriptions: Map<String, String>.from(data['metadataDescriptions'] ?? {}),

      extraMetadata: data['extraMetadata'] != null
          ? Map<String, dynamic>.from(data['extraMetadata'] as Map)
          : const {},
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'fileName': fileName,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'uploadedBy': uploadedBy,
      'storageUrl': storageUrl,
      'isPublic': isPublic,
      'metadata': metadata.toMap(),
      'generatedMetadata': generatedMetadata.toMap(),
      'metadataDescriptions': metadataDescriptions,
      'extraMetadata': extraMetadata,
    };
  }
}
