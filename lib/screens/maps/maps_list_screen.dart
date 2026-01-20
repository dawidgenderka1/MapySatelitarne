import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/maps_provider.dart';

class MapsListScreen extends ConsumerWidget {
  const MapsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mapsAsync = ref.watch(mapsStreamProvider);
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapy Satelitarne'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(mapsStreamProvider);
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authServiceProvider).signOut();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),
      body: mapsAsync.when(
        data: (maps) {
          if (maps.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.satellite_alt, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Brak dostępnych map'),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(mapsStreamProvider);
            },
            child: ListView.builder(
              itemCount: maps.length,
              padding: const EdgeInsets.all(8),
              itemBuilder: (context, index) {
                final map = maps[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.map, size: 40),
                    title: Text(map.metadata.title),
                    subtitle: Text(
                      '${map.metadata.source}\n${map.metadata.region}',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      context.go('/map/${map.id}');
                    },
                  ),
                );
              },
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
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(mapsStreamProvider),
                child: const Text('Spróbuj ponownie'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: authState.value?.isAnonymous == false
          ? FloatingActionButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Upload będzie dostępny wkrótce')),
                );
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
