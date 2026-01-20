import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadMap(File file, String mapId) async {
    final fileName = path.basename(file.path);
    final ref = _storage.ref().child('maps/$mapId/$fileName');
    
    final uploadTask = ref.putFile(file);
    final snapshot = await uploadTask;
    
    return await snapshot.ref.getDownloadURL();
  }

  Future<String> uploadThumbnail(File file, String mapId) async {
    final fileName = 'thumbnail_${path.basename(file.path)}';
    final ref = _storage.ref().child('thumbnails/$mapId/$fileName');
    
    final uploadTask = ref.putFile(file);
    final snapshot = await uploadTask;
    
    return await snapshot.ref.getDownloadURL();
  }

  Future<String> getDownloadUrl(String storagePath) async {
    final ref = _storage.ref(storagePath);
    return await ref.getDownloadURL();
  }

  Future<void> deleteFile(String storagePath) async {
    final ref = _storage.ref(storagePath);
    await ref.delete();
  }

  Future<String> uploadMapWithProgress(
    File file,
    String mapId,
    Function(double)? onProgress,
  ) async {
    final fileName = path.basename(file.path);
    final ref = _storage.ref().child('maps/$mapId/$fileName');
    
    final uploadTask = ref.putFile(file);
    
    uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
      final progress = snapshot.bytesTransferred / snapshot.totalBytes;
      onProgress?.call(progress);
    });
    
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  Future<String> uploadMapBytes({
    required String mapId,
    required Uint8List imageBytes,
    required String fileName,
    Function(double)? onProgress,
  }) async {
    final ref = _storage.ref().child('satellite_maps/$fileName');
    
    final uploadTask = ref.putData(
      imageBytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    
    if (onProgress != null) {
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress(progress);
      });
    }
    
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }
}