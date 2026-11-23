import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:signwell_flutter_poc_backend/documents.dart';
import 'package:signwell_flutter_poc_backend/signwell_client.dart';
import 'package:signwell_flutter_poc_backend/webhooks.dart';

/// Minimal backend for the Flutter proof of concept.
///
/// Endpoints:
///   POST /signing-sessions          {name, email} -> {document_id, signing_url}
///   GET  /documents/<id>            -> {id, status}
///   GET  /documents/<id>/signed.pdf -> the completed PDF
///   POST /webhooks/signwell         SignWell webhook receiver
///
/// This is a demo. A production backend must authenticate the app user and
/// only create or return documents that belong to that user.
Future<void> main() async {
  final env = _loadEnv();
  final apiKey = env['SIGNWELL_API_KEY'] ?? '';
  if (apiKey.isEmpty) {
    stderr.writeln('Set SIGNWELL_API_KEY (see backend/.env.example).');
    exit(1);
  }
  final testMode = (env['SIGNWELL_TEST_MODE'] ?? 'true') != 'false';
  final templateId = env['SIGNWELL_TEMPLATE_ID'] ?? '';
  final placeholder = env['SIGNWELL_TEMPLATE_PLACEHOLDER'] ?? 'Signer';
  final webhookId = env['SIGNWELL_WEBHOOK_ID'] ?? '';
  final port = int.tryParse(env['PORT'] ?? '') ?? 8080;

  final signwell = SignWellClient(apiKey: apiKey);
  final samplePdf =
      await File.fromUri(Platform.script.resolve('../assets/sample-agreement.pdf'))
          .readAsBytes();

  final app = Router()
    ..post('/signing-sessions', (Request req) async {
      final body = await _json(req);
      final name = (body['name'] as String?)?.trim() ?? '';
      final email = (body['email'] as String?)?.trim() ?? '';
      if (name.isEmpty || !email.contains('@')) {
        return _reply(400, {'error': 'name and a valid email are required'});
      }
      try {
        final doc = templateId.isNotEmpty
            ? await signwell.createDocumentFromTemplate(templateDocumentRequest(
                templateId: templateId,
                placeholderName: placeholder,
                signerName: name,
                signerEmail: email,
                testMode: testMode))
            : await signwell.createDocument(sampleDocumentRequest(
                pdfBytes: samplePdf,
                signerName: name,
                signerEmail: email,
                testMode: testMode));
        final url = embeddedSigningUrl(doc);
        if (url == null) {
          return _reply(502, {'error': 'SignWell returned no embedded_signing_url'});
        }
        stdout.writeln('Created document ${doc['id']} (test_mode: $testMode)');
        return _reply(200, {'document_id': doc['id'], 'signing_url': url});
      } on SignWellException catch (e) {
        stderr.writeln(e);
        return _reply(502, {'error': 'SignWell error ${e.statusCode}'});
      }
    })
    ..get('/documents/<id>', (Request req, String id) async {
      try {
        final doc = await signwell.getDocument(id);
        return _reply(200, {'id': doc['id'], 'status': doc['status']});
      } on SignWellException catch (e) {
        return _reply(e.statusCode == 404 ? 404 : 502, {'error': '$e'});
      }
    })
    ..get('/documents/<id>/signed.pdf', (Request req, String id) async {
      try {
        final pdf = await signwell.getCompletedPdf(id);
        return Response.ok(pdf, headers: {'Content-Type': 'application/pdf'});
      } on SignWellException catch (e) {
        return _reply(e.statusCode == 404 ? 404 : 502, {'error': '$e'});
      }
    })
    ..post('/webhooks/signwell', (Request req) async {
      final payload = await _json(req);
      if (webhookId.isEmpty || !verifySignWellEvent(payload, webhookId)) {
        return _reply(401, {'error': 'invalid event hash'});
      }
      final event = payload['event'] as Map;
      final docId = (payload['data'] as Map?)?['object']?['id'];
      // Don't trust the body beyond the event type: re-fetch the document.
      final status = docId == null
          ? null
          : (await signwell.getDocument(docId as String))['status'];
      stdout.writeln('Webhook ${event['type']} for $docId, status now $status');
      // In a real app: mark the document signed in your database here.
      return _reply(200, {'ok': true});
    })
    ..get('/healthz', (Request req) => Response.ok('ok'));

  final handler = const Pipeline().addMiddleware(logRequests()).addHandler(app.call);
  final server = await io.serve(handler, InternetAddress.anyIPv4, port);
  stdout.writeln('Backend listening on http://${server.address.host}:${server.port}');
}

Future<Map<String, dynamic>> _json(Request req) async {
  try {
    final decoded = jsonDecode(await req.readAsString());
    return decoded is Map<String, dynamic> ? decoded : {};
  } on FormatException {
    return {};
  }
}

Response _reply(int status, Object body) => Response(status,
    body: jsonEncode(body), headers: {'Content-Type': 'application/json'});

/// Reads environment variables, plus a local .env file if present.
Map<String, String> _loadEnv() {
  final values = <String, String>{};
  final file = File.fromUri(Platform.script.resolve('../.env'));
  if (file.existsSync()) {
    for (final line in file.readAsLinesSync()) {
      final t = line.trim();
      if (t.isEmpty || t.startsWith('#') || !t.contains('=')) continue;
      final i = t.indexOf('=');
      values[t.substring(0, i).trim()] = t.substring(i + 1).trim();
    }
  }
  values.addAll(Platform.environment);
  return values;
}
