import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Thin wrapper around the SignWell REST API (https://developers.signwell.com).
///
/// Only the calls this proof of concept needs. Runs on your server: the API key
/// must never be shipped inside a mobile app.
class SignWellClient {
  SignWellClient({
    required this.apiKey,
    http.Client? httpClient,
    this.baseUrl = 'https://www.signwell.com/api/v1',
  }) : _http = httpClient ?? http.Client();

  final String apiKey;
  final String baseUrl;
  final http.Client _http;

  Map<String, String> get _headers => {
        'X-Api-Key': apiKey,
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  /// Creates a document from a PDF and returns the API response.
  Future<Map<String, dynamic>> createDocument(Map<String, dynamic> body) =>
      _send('POST', '/documents', body);

  /// Creates a document from a template you built in SignWell.
  Future<Map<String, dynamic>> createDocumentFromTemplate(
          Map<String, dynamic> body) =>
      _send('POST', '/document_templates/documents', body);

  Future<Map<String, dynamic>> getDocument(String id) =>
      _send('GET', '/documents/${Uri.encodeComponent(id)}');

  /// Downloads the signed PDF. SignWell can return 404 for a few seconds after
  /// a document completes while the final PDF is generated, so this retries.
  Future<Uint8List> getCompletedPdf(
    String id, {
    int attempts = 6,
    Duration delay = const Duration(seconds: 2),
  }) async {
    final uri = Uri.parse(
        '$baseUrl/documents/${Uri.encodeComponent(id)}/completed_pdf?url_only=false&audit_page=true');
    for (var i = 1; ; i++) {
      final res = await _http.get(uri, headers: {'X-Api-Key': apiKey});
      if (res.statusCode == 200) return res.bodyBytes;
      if (res.statusCode == 404 && i < attempts) {
        await Future<void>.delayed(delay);
        continue;
      }
      throw SignWellException(res.statusCode, res.body);
    }
  }

  Future<Map<String, dynamic>> _send(
      String method, String path, [Map<String, dynamic>? body]) async {
    final req = http.Request(method, Uri.parse('$baseUrl$path'))
      ..headers.addAll(_headers);
    if (body != null) req.body = jsonEncode(body);
    final res = await http.Response.fromStream(await _http.send(req));
    if (res.statusCode >= 400) {
      throw SignWellException(res.statusCode, res.body);
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}

class SignWellException implements Exception {
  SignWellException(this.statusCode, this.body);
  final int statusCode;
  final String body;

  @override
  String toString() => 'SignWell API error $statusCode: $body';
}

/// Returns the embedded signing URL for the first recipient that has one.
String? embeddedSigningUrl(Map<String, dynamic> document) {
  final recipients = document['recipients'];
  if (recipients is! List) return null;
  for (final r in recipients) {
    if (r is Map && r['embedded_signing_url'] is String) {
      return r['embedded_signing_url'] as String;
    }
  }
  return null;
}
