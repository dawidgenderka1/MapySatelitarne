import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:go_router/go_router.dart';
import '../../services/image_url_service.dart';

class MapViewerScreen extends StatefulWidget {
  final String imageUrl;
  final String title;

  const MapViewerScreen({
    super.key,
    required this.imageUrl,
    required this.title,
  });

  @override
  State<MapViewerScreen> createState() => _MapViewerScreenState();
}

class _MapViewerScreenState extends State<MapViewerScreen> {
  final PhotoViewController _controller = PhotoViewController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _zoomIn() {
    final currentScale = _controller.scale ?? 1.0;
    _controller.scale = currentScale * 1.5;
  }

  void _zoomOut() {
    final currentScale = _controller.scale ?? 1.0;
    _controller.scale = currentScale / 1.5;
  }

  void _resetZoom() {
    _controller.scale = 1.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => context.pop(),
          tooltip: 'Zamknij',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_out, color: Colors.white),
            onPressed: _zoomOut,
            tooltip: 'Oddal',
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in, color: Colors.white),
            onPressed: _zoomIn,
            tooltip: 'Przybliż',
          ),
          IconButton(
            icon: const Icon(Icons.fit_screen, color: Colors.white),
            onPressed: _resetZoom,
            tooltip: 'Dopasuj',
          ),
        ],
      ),
      body: Stack(
        children: [
          PhotoView(
            imageProvider: NetworkImage(
              ImageUrlService.getProxiedUrl(widget.imageUrl),
            ),
            controller: _controller,
            minScale: PhotoViewComputedScale.contained * 0.5,
            maxScale: PhotoViewComputedScale.covered * 4,
            initialScale: PhotoViewComputedScale.contained,
            backgroundDecoration: const BoxDecoration(
              color: Colors.black,
            ),
            enableRotation: false,
            loadingBuilder: (context, event) => Center(
              child: CircularProgressIndicator(
                value: event == null
                    ? 0
                    : event.cumulativeBytesLoaded / (event.expectedTotalBytes ?? 1),
                color: Colors.white,
              ),
            ),
            errorBuilder: (context, error, stackTrace) {
              print('Błąd PhotoView: $error');
              print('URL: ${widget.imageUrl}');
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 60, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text(
                      'Nie można załadować obrazu',
                      style: TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'URL: ${widget.imageUrl}',
                      style: const TextStyle(color: Colors.white70, fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: 'zoom_in',
                  mini: true,
                  onPressed: _zoomIn,
                  backgroundColor: Colors.white.withOpacity(0.9),
                  child: const Icon(Icons.add, color: Colors.black),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'zoom_out',
                  mini: true,
                  onPressed: _zoomOut,
                  backgroundColor: Colors.white.withOpacity(0.9),
                  child: const Icon(Icons.remove, color: Colors.black),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'reset',
                  mini: true,
                  onPressed: _resetZoom,
                  backgroundColor: Colors.white.withOpacity(0.9),
                  child: const Icon(Icons.fit_screen, color: Colors.black),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
