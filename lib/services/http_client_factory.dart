/// Centralized HTTP client factory.
///
/// Provides an SSL-safe [http.Client] for all API services.
/// In debug mode, bypasses certificate verification to allow ngrok
/// tunnels (which can cause HandshakeException on some Android devices).
///
/// **Note:** main.dart also sets [HttpOverrides.global] as a global
/// fallback. This factory provides defense-in-depth for explicit clients.
library;

import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Creates an [http.Client] suitable for the current environment.
///
/// - **Debug + non-web**: Returns an [IOClient] that accepts all certificates
///   (needed for ngrok HTTPS tunnels on physical Android devices).
/// - **Release / Web**: Returns the standard [http.Client].
http.Client createHttpClient() {
  if (!kIsWeb && kDebugMode) {
    final ioClient = HttpClient()
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
    debugPrint('[SSL] createHttpClient: IOClient with cert bypass created');
    return IOClient(ioClient);
  }
  return http.Client();
}
