import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/maps_provider.dart';
import '../../models/map_metadata.dart';

class MetadataEditScreen extends ConsumerStatefulWidget {
  final String mapId;

  const MetadataEditScreen({super.key, required this.mapId});

  @override
  ConsumerState<MetadataEditScreen> createState() => _MetadataEditScreenState();
}

class _MetadataEditScreenState extends ConsumerState<MetadataEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _sourceController;
  late TextEditingController _regionController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _sourceController = TextEditingController();
    _regionController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _sourceController.dispose();
    _regionController.dispose();
    super.dispose();
  }

  Future<void> _saveMetadata() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final metadata = MapMetadata(
        title: _titleController.text,
        description: _descriptionController.text,
        source: _sourceController.text,
        region: _regionController.text,
        acquisitionDate: DateTime.now(),
      );

      await ref.read(firestoreServiceProvider).updateMetadata(widget.mapId, metadata);

      ref.invalidate(mapProvider(widget.mapId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Metadane zaktualizowane')),
        );
        context.go('/map/${widget.mapId}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapAsync = ref.watch(mapProvider(widget.mapId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edycja metadanych'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/map/${widget.mapId}'),
        ),
      ),
      body: mapAsync.when(
        data: (map) {
          if (map == null) {
            return const Center(child: Text('Mapa nie znaleziona'));
          }

          if (_titleController.text.isEmpty) {
            _titleController.text = map.metadata.title;
            _descriptionController.text = map.metadata.description;
            _sourceController.text = map.metadata.source;
            _regionController.text = map.metadata.region;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Tytuł',
                      border: const OutlineInputBorder(),
                      helperText: map.metadataDescriptions['title'],
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Wprowadź tytuł';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Opis',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _sourceController,
                    decoration: InputDecoration(
                      labelText: 'Źródło',
                      border: const OutlineInputBorder(),
                      helperText: map.metadataDescriptions['source'],
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Wprowadź źródło';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _regionController,
                    decoration: InputDecoration(
                      labelText: 'Region',
                      border: const OutlineInputBorder(),
                      helperText: map.metadataDescriptions['region'],
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Wprowadź region';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveMetadata,
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text('Zapisz zmiany'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Błąd: $error'),
        ),
      ),
    );
  }
}
