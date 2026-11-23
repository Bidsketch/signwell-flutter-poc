import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:signwell_flutter_poc_backend/documents.dart';
import 'package:signwell_flutter_poc_backend/signwell_client.dart';
import 'package:signwell_flutter_poc_backend/webhooks.dart';
import 'package:test/test.dart';

void main() {
  group('verifySignWellEvent', () {
    const webhookId = 'a1b2c3d4-0000-0000-0000-000000000000';
    Map<String, dynamic> event(String hash) => {
          'event': {'type': 'document_completed', 'time': 1700000000, 'hash': hash},
          'data': {'object': {'id': 'doc_1'}},
        };
    final good = Hmac(sha256, utf8.encode(webhookId))
        .convert(utf8.encode('document_completed@1700000000'))
        .toString();

    test('accepts a correctly signed event', () {
      expect(verifySignWellEvent(event(good), webhookId), isTrue);
    });
    test('rejects a wrong hash or wrong webhook id', () {
      expect(verifySignWellEvent(event('0' * 64), webhookId), isFalse);
      expect(verifySignWellEvent(event(good), 'other-id'), isFalse);
    });
    test('rejects malformed payloads', () {
      expect(verifySignWellEvent({}, webhookId), isFalse);
      expect(verifySignWellEvent({'event': 'x'}, webhookId), isFalse);
    });
  });

  test('sample document request enables embedded signing', () {
    final body = sampleDocumentRequest(
        pdfBytes: Uint8List.fromList([1, 2, 3]),
        signerName: 'Dana Demo',
        signerEmail: 'dana@example.com',
        testMode: true);
    expect(body['embedded_signing'], isTrue);
    expect(body['test_mode'], isTrue);
    expect((body['files'] as List).single['file_base64'], 'AQID');
    final fields = (body['fields'] as List).single as List;
    expect(fields.map((f) => f['type']), ['signature', 'text', 'date']);
  });

  test('embeddedSigningUrl reads the first recipient URL', () {
    expect(
        embeddedSigningUrl({
          'recipients': [
            {'id': '1', 'embedded_signing_url': 'https://www.signwell.com/x'}
          ]
        }),
        'https://www.signwell.com/x');
    expect(embeddedSigningUrl({'recipients': []}), isNull);
  });
}
