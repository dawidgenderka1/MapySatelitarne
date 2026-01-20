class ImageUrlService {
  static const String _proxyBaseUrl = 
      'https://us-central1-satellite-maps-b761c.cloudfunctions.net/getImageProxy';

  static String getProxiedUrl(String originalUrl) {
    return '$_proxyBaseUrl?url=${Uri.encodeComponent(originalUrl)}';
  }
}
