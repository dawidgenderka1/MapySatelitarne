import 'package:go_router/go_router.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/maps/maps_list_screen.dart';
import '../../screens/maps/map_detail_screen.dart';
import '../../screens/maps/map_viewer_screen.dart';
import '../../screens/metadata/metadata_edit_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      name: 'register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/maps',
      name: 'maps',
      builder: (context, state) => const MapsListScreen(),
    ),
    GoRoute(
      path: '/map/:id',
      name: 'map-detail',
      builder: (context, state) {
        final mapId = state.pathParameters['id']!;
        return MapDetailScreen(mapId: mapId);
      },
    ),
    GoRoute(
      path: '/map/:id/view',
      name: 'map-viewer',
      builder: (context, state) {
        final imageUrl = state.uri.queryParameters['imageUrl'] ?? '';
        final title = state.uri.queryParameters['title'] ?? '';
        return MapViewerScreen(
          imageUrl: imageUrl,
          title: title,
        );
      },
    ),
    GoRoute(
      path: '/map/:id/edit-metadata',
      name: 'edit-metadata',
      builder: (context, state) {
        final mapId = state.pathParameters['id']!;
        return MetadataEditScreen(mapId: mapId);
      },
    ),
  ],
);
