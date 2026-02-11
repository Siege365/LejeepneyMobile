import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;

/// Custom tile provider with better error handling and retry logic
class ResilientTileProvider extends TileProvider {
  final int maxRetries;
  final Duration retryDelay;
  final String userAgent;
  final http.Client _client = http.Client();

  ResilientTileProvider({
    this.maxRetries = 2,
    this.retryDelay = const Duration(milliseconds: 500),
    this.userAgent = 'FlutterMap',
  });

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return ResilientNetworkImage(
      getTileUrl(coordinates, options),
      client: _client,
      headers: {'User-Agent': userAgent},
      maxRetries: maxRetries,
      retryDelay: retryDelay,
    );
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}

/// Network image provider with retry logic
class ResilientNetworkImage extends ImageProvider<ResilientNetworkImage> {
  final String url;
  final http.Client client;
  final Map<String, String> headers;
  final int maxRetries;
  final Duration retryDelay;

  const ResilientNetworkImage(
    this.url, {
    required this.client,
    required this.headers,
    this.maxRetries = 2,
    this.retryDelay = const Duration(milliseconds: 500),
  });

  @override
  Future<ResilientNetworkImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<ResilientNetworkImage>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    ResilientNetworkImage key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
      debugLabel: url,
    );
  }

  Future<ui.Codec> _loadAsync(
    ResilientNetworkImage key,
    ImageDecoderCallback decode,
  ) async {
    Exception? lastError;

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final response = await client
            .get(Uri.parse(url), headers: headers)
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final bytes = response.bodyBytes;
          if (bytes.isEmpty) {
            throw Exception('Empty response body');
          }

          final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
          return decode(buffer);
        } else if (response.statusCode == 404) {
          // Don't retry 404s
          throw Exception('Tile not found (404)');
        } else {
          throw Exception('HTTP ${response.statusCode}');
        }
      } on http.ClientException catch (e) {
        lastError = e;
        // Network errors are often transient, retry them
        if (attempt < maxRetries) {
          await Future.delayed(retryDelay * (attempt + 1));
          continue;
        }
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        // Don't retry other errors
        break;
      }
    }

    // All retries failed, throw a silent error
    if (kDebugMode) {
      debugPrint('Tile load failed after ${maxRetries + 1} attempts: $url');
    }

    // Return a 1x1 transparent image instead of throwing
    // This prevents the exception spam in console
    final emptyBytes = Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, // 1x1
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
      0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
      0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
      0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
      0x42, 0x60, 0x82,
    ]);

    final buffer = await ui.ImmutableBuffer.fromUint8List(emptyBytes);
    return decode(buffer);
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is ResilientNetworkImage && other.url == url;
  }

  @override
  int get hashCode => url.hashCode;
}
