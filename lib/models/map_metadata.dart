import 'package:cloud_firestore/cloud_firestore.dart';

class MapMetadata {
  final String title;
  final String description;
  final String source;
  final DateTime acquisitionDate;
  final String region;
  final Coordinates coordinates;
  final String resolution;
  final List<String> bands;
  final double cloudCoverage;
  final int fileSize;
  final ImageDimensions dimensions;
  final String format;
  final String colorSpace;

  MapMetadata({
    required this.title,
    required this.description,
    required this.source,
    required this.acquisitionDate,
    required this.region,
    required this.coordinates,
    required this.resolution,
    required this.bands,
    required this.cloudCoverage,
    required this.fileSize,
    required this.dimensions,
    required this.format,
    required this.colorSpace,
  });

  factory MapMetadata.fromMap(Map<String, dynamic> map) {
    return MapMetadata(
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      source: map['source'] ?? '',
      acquisitionDate: (map['acquisitionDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      region: map['region'] ?? '',
      coordinates: Coordinates.fromMap(map['coordinates'] ?? {}),
      resolution: map['resolution'] ?? '',
      bands: List<String>.from(map['bands'] ?? []),
      cloudCoverage: (map['cloudCoverage'] ?? 0).toDouble(),
      fileSize: map['fileSize'] ?? 0,
      dimensions: ImageDimensions.fromMap(map['dimensions'] ?? {}),
      format: map['format'] ?? '',
      colorSpace: map['colorSpace'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'source': source,
      'acquisitionDate': Timestamp.fromDate(acquisitionDate),
      'region': region,
      'coordinates': coordinates.toMap(),
      'resolution': resolution,
      'bands': bands,
      'cloudCoverage': cloudCoverage,
      'fileSize': fileSize,
      'dimensions': dimensions.toMap(),
      'format': format,
      'colorSpace': colorSpace,
    };
  }
}

class Coordinates {
  final double lat;
  final double lng;

  Coordinates({required this.lat, required this.lng});

  factory Coordinates.fromMap(Map<String, dynamic> map) {
    return Coordinates(
      lat: (map['lat'] ?? 0).toDouble(),
      lng: (map['lng'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {'lat': lat, 'lng': lng};
}

class ImageDimensions {
  final int width;
  final int height;

  ImageDimensions({required this.width, required this.height});

  factory ImageDimensions.fromMap(Map<String, dynamic> map) {
    return ImageDimensions(
      width: map['width'] ?? 0,
      height: map['height'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {'width': width, 'height': height};
}

class GeneratedMetadata {
  final int viewCount;
  final int downloadCount;
  final double averageRating;
  final DateTime? lastViewed;
  final String processingStatus;

  GeneratedMetadata({
    required this.viewCount,
    required this.downloadCount,
    required this.averageRating,
    this.lastViewed,
    required this.processingStatus,
  });

  factory GeneratedMetadata.fromMap(Map<String, dynamic> map) {
    return GeneratedMetadata(
      viewCount: map['viewCount'] ?? 0,
      downloadCount: map['downloadCount'] ?? 0,
      averageRating: (map['averageRating'] ?? 0).toDouble(),
      lastViewed: (map['lastViewed'] as Timestamp?)?.toDate(),
      processingStatus: map['processingStatus'] ?? 'pending',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'viewCount': viewCount,
      'downloadCount': downloadCount,
      'averageRating': averageRating,
      'lastViewed': lastViewed != null ? Timestamp.fromDate(lastViewed!) : null,
      'processingStatus': processingStatus,
    };
  }
}