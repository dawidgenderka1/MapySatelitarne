import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/maps_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/image_url_service.dart';
import '../../models/satellite_map.dart';

class MapDetailScreen extends ConsumerStatefulWidget {
  final String mapId;

  const MapDetailScreen({super.key, required this.mapId});

  @override
  ConsumerState<MapDetailScreen> createState() => _MapDetailScreenState();
}

class _MapDetailScreenState extends ConsumerState<MapDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      try {
        await ref.read(cloudFunctionsServiceProvider).recordMapView(widget.mapId);
        ref.invalidate(mapProvider(widget.mapId));
      } catch (e) {
        print('Błąd rejestracji wyświetlenia: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mapAsync = ref.watch(mapProvider(widget.mapId));
    final userDataAsync = ref.watch(currentUserDataProvider);
    final authState = ref.watch(authStateProvider);
    final isAnonymous = authState.value?.isAnonymous ?? true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Szczegóły mapy'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/maps'),
        ),
      ),
      body: mapAsync.when(
        data: (map) {
          if (map == null) {
            return const Center(
              child: Text('Mapa nie została znaleziona'),
            );
          }

          final extraMetadata = map.extraMetadata;
          final extraKeys = extraMetadata.keys.toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GestureDetector(
                  onTap: () {
                    context.push('/map/${widget.mapId}/view?imageUrl=${Uri.encodeComponent(map.storageUrl)}&title=${Uri.encodeComponent(map.metadata.title)}');
                  },
                  child: Container(
                    height: 300,
                    color: Colors.grey[300],
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          ImageUrlService.getProxiedUrl(map.storageUrl),
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            print('Błąd ładowania obrazu: $error');
                            print('URL: ${map.storageUrl}');
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.image_not_supported, size: 60, color: Colors.red),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Nie można załadować obrazu',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        Positioned(
                          bottom: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.zoom_in, color: Colors.white, size: 20),
                                SizedBox(width: 5),
                                Text(
                                  'Kliknij aby powiększyć',
                                  style: TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isAnonymous) ...[
                        const Card(
                          color: Colors.blue,
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.white),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Zaloguj się aby zobaczyć metadane mapy',
                                    style: TextStyle(color: Colors.white, fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        Text(
                          map.metadata.title,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          map.metadata.description,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Metadane',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Divider(),
                        _buildMetadataRow('Źródło', map.metadata.source, map.metadataDescriptions['source']),
                        _buildMetadataRow('Region', map.metadata.region, map.metadataDescriptions['region']),
                        _buildMetadataRow(
                          'Data pozyskania',
                          DateFormat('dd.MM.yyyy').format(map.metadata.acquisitionDate),
                          map.metadataDescriptions['acquisitionDate'],
                        ),
                        _buildMetadataRow('Nazwa pliku', map.fileName, null),

                        if (extraKeys.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Text(
                            'Dodatkowe metadane',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const Divider(),
                          for (final key in extraKeys)
                            _buildMetadataRow(
                              key,
                              (extraMetadata[key] ?? '').toString(),
                              null,
                            ),
                        ],

                        const SizedBox(height: 16),
                        const Text(
                          'Statystyki',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Divider(),
                        _buildMetadataRow('Wyświetlenia', map.generatedMetadata.viewCount.toString(), null),
                        if (map.generatedMetadata.lastViewed != null)
                          _buildMetadataRow(
                            'Ostatnio oglądana',
                            DateFormat('dd.MM.yyyy HH:mm').format(map.generatedMetadata.lastViewed!),
                            null,
                          ),
                        const SizedBox(height: 16),
                        if (userDataAsync.value?.canEdit == true)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                context.go('/map/${widget.mapId}/edit-metadata');
                              },
                              icon: const Icon(Icons.edit),
                              label: const Text('Edytuj metadane'),
                            ),
                          ),
                        if (userDataAsync.value?.canDelete == true) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _showDeleteConfirmation(context, map),
                              icon: const Icon(Icons.delete),
                              label: const Text('Usuń mapę'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.red),
              const SizedBox(height: 16),
              Text('Błąd: $error'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataRow(String label, String value, String? description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 140,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          if (description != null)
            Padding(
              padding: const EdgeInsets.only(left: 140, top: 4),
              child: Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showDeleteConfirmation(BuildContext context, SatelliteMap map) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Usuń mapę'),
        content: Text('Czy na pewno chcesz usunąć mapę "${map.metadata.title}"? Ta operacja jest nieodwracalna.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Anuluj'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final storageService = ref.read(storageServiceProvider);
        final firestoreService = ref.read(firestoreServiceProvider);

        final fileName = map.storageUrl.split('/o/')[1].split('?')[0];
        final decodedFileName = Uri.decodeComponent(fileName);

        await storageService.deleteFile(decodedFileName);
        await firestoreService.deleteMap(widget.mapId);

        ref.invalidate(mapsStreamProvider);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mapa została usunięta')),
          );
          context.go('/maps');
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Błąd usuwania: $e')),
          );
        }
      }
    }
  }
}
