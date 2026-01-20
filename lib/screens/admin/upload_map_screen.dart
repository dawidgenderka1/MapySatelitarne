import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'dart:typed_data';
import '../../models/map_metadata.dart';
import '../../models/satellite_map.dart';
import '../../providers/maps_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';

class UploadMapScreen extends ConsumerStatefulWidget {
  const UploadMapScreen({super.key});

  @override
  ConsumerState<UploadMapScreen> createState() => _UploadMapScreenState();
}

class _UploadMapScreenState extends ConsumerState<UploadMapScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _sourceController = TextEditingController();
  final _regionController = TextEditingController();
  
  XFile? _selectedImage;
  Uint8List? _imageBytes;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  DateTime _acquisitionDate = DateTime.now();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _sourceController.dispose();
    _regionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
    );

    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _selectedImage = image;
        _imageBytes = bytes;
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _acquisitionDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _acquisitionDate = picked;
      });
    }
  }

  Future<void> _uploadMap() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wybierz obraz mapy')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      final currentUser = ref.read(authStateProvider).value;
      if (currentUser == null) throw Exception('Użytkownik niezalogowany');

      const uuid = Uuid();
      final mapId = uuid.v4();
      final fileName = '${mapId}.jpg';

      final storageService = ref.read(storageServiceProvider);
      final downloadUrl = await storageService.uploadMapBytes(
        mapId: mapId,
        imageBytes: _imageBytes!,
        fileName: fileName,
        onProgress: (progress) {
          setState(() {
            _uploadProgress = progress;
          });
        },
      );

      final metadata = MapMetadata(
        title: _titleController.text,
        description: _descriptionController.text,
        source: _sourceController.text,
        region: _regionController.text,
        acquisitionDate: _acquisitionDate,
      );

      final generatedMetadata = GeneratedMetadata(
        viewCount: 0,
      );

      final satelliteMap = SatelliteMap(
        id: mapId,
        fileName: fileName,
        uploadedAt: DateTime.now(),
        uploadedBy: currentUser.uid,
        storageUrl: downloadUrl,
        isPublic: true,
        metadata: metadata,
        generatedMetadata: generatedMetadata,
        metadataDescriptions: {
          'title': 'Tytuł mapy satelitarnej',
          'description': 'Opis mapy',
          'source': 'Źródło danych (np. Copernicus)',
          'region': 'Region geograficzny',
          'acquisitionDate': 'Data akwizycji danych',
        },
      );

      await ref.read(firestoreServiceProvider).addMap(satelliteMap);

      ref.invalidate(mapsStreamProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mapa została przesłana')),
        );
        context.go('/maps');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prześlij mapę satelitarną'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/maps'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: InkWell(
                  onTap: _isUploading ? null : _pickImage,
                  child: Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _imageBytes != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              _imageBytes!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate, size: 64, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('Kliknij aby wybrać obraz'),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Tytuł',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value?.isEmpty == true ? 'Tytuł jest wymagany' : null,
                enabled: !_isUploading,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Opis',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                enabled: !_isUploading,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _sourceController,
                decoration: const InputDecoration(
                  labelText: 'Źródło',
                  hintText: 'np. Copernicus Sentinel-2',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value?.isEmpty == true ? 'Źródło jest wymagane' : null,
                enabled: !_isUploading,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _regionController,
                decoration: const InputDecoration(
                  labelText: 'Region',
                  hintText: 'np. Europa Środkowa',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value?.isEmpty == true ? 'Region jest wymagany' : null,
                enabled: !_isUploading,
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Data akwizycji'),
                subtitle: Text('${_acquisitionDate.day}.${_acquisitionDate.month}.${_acquisitionDate.year}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: _isUploading ? null : _selectDate,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.shade400),
                ),
              ),
              const SizedBox(height: 24),
              if (_isUploading)
                Column(
                  children: [
                    LinearProgressIndicator(value: _uploadProgress),
                    const SizedBox(height: 8),
                    Text('Przesyłanie: ${(_uploadProgress * 100).toStringAsFixed(0)}%'),
                    const SizedBox(height: 16),
                  ],
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isUploading ? null : _uploadMap,
                  icon: const Icon(Icons.upload),
                  label: Text(_isUploading ? 'Przesyłanie...' : 'Prześlij mapę'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
