import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/maps_provider.dart';
import '../../providers/auth_provider.dart';

class MapDetailScreen extends ConsumerWidget {
  final String mapId;

  const MapDetailScreen({super.key, required this.mapId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mapAsync = ref.watch(mapProvider(mapId));
    final currentUser = ref.watch(authStateProvider).value;

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

          ref.read(firestoreServiceProvider).incrementViewCount(mapId);

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GestureDetector(
                  onTap: () {
                    context.go('/map/$mapId/view?imageUrl=${Uri.encodeComponent(map.storageUrl)}&title=${Uri.encodeComponent(map.metadata.title)}');
                  },
                  child: Container(
                    height: 300,
                    color: Colors.grey[300],
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          map.storageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(Icons.image_not_supported, size: 60),
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
                        null,
                      ),
                      _buildMetadataRow('Nazwa pliku', map.fileName, null),
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
                      if (currentUser?.isAnonymous == false)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              context.go('/map/$mapId/edit-metadata');
                            },
                            icon: const Icon(Icons.edit),
                            label: const Text('Edytuj metadane'),
                          ),
                        ),
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
}
