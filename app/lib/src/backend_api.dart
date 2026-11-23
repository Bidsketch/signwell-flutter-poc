import 'dart:convert';

import 'package:http/http.dart' as http;

/// Your backend's URL. Override with --dart-define=BACKEND_URL=https://...
///
/// The default works for the Android emulator talking to a backend on your
/// computer (10.0.2.2 is the host machine). On the iOS simulator use
/// http://localhost:8080.
const backendUrl = String.fromEnvironment(
  'BACKEND_URL',
  defaultValue: 'http://10.0.2.2:8080',
);

class SigningSession {
  const SigningSession({required this.documentId, required this.signingUrl});
  final String documentId;
  final String signingUrl;
}

/// Talks to the proof-of-concept backend. The app never sees the SignWell API
/// key; the backend creates the document and returns only the signing URL.
class BackendApi {
  BackendApi({http.Client? client, String? baseUrl})
      : _http = client ?? http.Client(),
        _base = baseUrl ?? backendUrl;

  final http.Client _http;
  final String _base;

  Future<SigningSession> createSigningSession({
    required String name,
    required String email,
  }) async {
    final res = await _http.post(
      Uri.parse('$_base/signing-sessions'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'email': email}),
    );
    final body = _decode(res);
    return SigningSession(
      documentId: body['document_id'] as String,
      signingUrl: body['signing_url'] as String,
    );
  }

  /// Asks the backend for the document's status as SignWell reports it.
  /// Use this (or your webhook) as the source of truth, not the in-app event.
  Future<String> documentStatus(String documentId) async {
    final res = await _http
        .get(Uri.parse('$_base/documents/${Uri.encodeComponent(documentId)}'));
    return _decode(res)['status'] as String;
  }

  Map<String, dynamic> _decode(http.Response res) {
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw BackendException(body['error']?.toString() ?? 'HTTP ${res.statusCode}');
    }
    return body;
  }
}

class BackendException implements Exception {
  BackendException(this.message);
  final String message;
  @override
  String toString() => message;
}
