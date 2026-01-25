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
  final List<TextEditingController> _extraKeyControllers = [];
  final List<TextEditingController> _extraValueControllers = [];

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

    for (final c in _extraKeyControllers) {
      c.dispose();
    }
    for (final c in _extraValueControllers) {
      c.dispose();
    }

    super.dispose();
  }

  void _addExtraField({String key = '', String value = ''}) {
    setState(() {
      _extraKeyControllers.add(TextEditingController(text: key));
      _extraValueControllers.add(TextEditingController(text: value));
    });
  }

  void _removeExtraField(int index) {
    setState(() {
      _extraKeyControllers[index].dispose();
      _extraValueControllers[index].dispose();
      _extraKeyControllers.removeAt(index);
      _extraValueControllers.removeAt(index);
    });
  }

  Map<String, dynamic> _buildExtraMetadataMap() {
    final Map<String, dynamic> result = {};
    for (int i = 0; i < _extraKeyControllers.length; i++) {
      final key = _extraKeyControllers[i].text.trim();
      final value = _extraValueControllers[i].text.trim();
      if (key.isEmpty) continue;
      result[key] = value;
    }
    return result;
  }

  String? _validateExtraKeysUnique() {
    final seen = <String>{};
    for (final c in _extraKeyControllers) {
      final k = c.text.trim();
      if (k.isEmpty) continue;
      final lower = k.toLowerCase();
      if (seen.contains(lower)) {
        return 'Klucze w dodatkowych metadanych nie mogą się powtarzać (duplikat: "$k").';
      }
      seen.add(lower);
    }
    return null;
  }

  Future<void> _saveMetadata() async {
    if (!_formKey.currentState!.validate()) return;

    final extraErr = _validateExtraKeysUnique();
    if (extraErr != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(extraErr)),
        );
      }
      return;
    }

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
      final extraMetadata = _buildExtraMetadataMap();

      await ref.read(firestoreServiceProvider).updateExtraMetadata(widget.mapId, extraMetadata);

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

            if (_extraKeyControllers.isEmpty && _extraValueControllers.isEmpty) {
              final extra = map.extraMetadata;
              final keys = extra.keys.toList()
                ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
              for (final k in keys) {
                _addExtraField(key: k, value: (extra[k] ?? '').toString());
              }

              if (keys.isEmpty) {
                _addExtraField();
              }
            }
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
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Dodatkowe metadane (opcjonalne)',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _isLoading ? null : () => _addExtraField(),
                        icon: const Icon(Icons.add),
                        label: const Text('Dodaj'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  for (int i = 0; i < _extraKeyControllers.length; i++) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 4,
                          child: TextFormField(
                            controller: _extraKeyControllers[i],
                            decoration: const InputDecoration(
                              labelText: 'Klucz',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final v = (value ?? '').trim();
                              final val = _extraValueControllers[i].text.trim();
                              if (v.isEmpty && val.isNotEmpty) {
                                return 'Podaj klucz lub usuń wiersz';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 6,
                          child: TextFormField(
                            controller: _extraValueControllers[i],
                            decoration: const InputDecoration(
                              labelText: 'Wartość',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _isLoading ? null : () => _removeExtraField(i),
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Usuń pole',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

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
