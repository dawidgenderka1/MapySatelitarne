import 'package:cloud_firestore/cloud_firestore.dart';

class MapMetadata {
  final String title;
  final String description;
  final String source;
  final DateTime acquisitionDate;
  final String region;

  MapMetadata({
    required this.title,
    required this.description,
    required this.source,
    required this.acquisitionDate,
    required this.region,
  });

  factory MapMetadata.fromMap(Map<String, dynamic> map) {
    return MapMetadata(
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      source: map['source'] ?? '',
      acquisitionDate: (map['acquisitionDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      region: map['region'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'source': source,
      'acquisitionDate': Timestamp.fromDate(acquisitionDate),
      'region': region,
    };
  }
}

class GeneratedMetadata {
  final int viewCount;
  final DateTime? lastViewed;

  GeneratedMetadata({
    required this.viewCount,
    this.lastViewed,
  });

  factory GeneratedMetadata.fromMap(Map<String, dynamic> map) {
    return GeneratedMetadata(
      viewCount: map['viewCount'] ?? 0,
      lastViewed: (map['lastViewed'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'viewCount': viewCount,
      'lastViewed': lastViewed != null ? Timestamp.fromDate(lastViewed!) : null,
    };
  }
}
