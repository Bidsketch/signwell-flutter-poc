import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:signwell_flutter_poc/main.dart';
import 'package:signwell_flutter_poc/src/backend_api.dart';
import 'package:signwell_flutter_poc/src/signwell_bridge.dart';

void main() {
  group('buildSigningPage', () {
    final template = File('assets/signwell_signing.html').readAsStringSync();

    test('injects the URL as a JSON string', () {
      const url = 'https://www.signwell.com/embedded/sign/abc/?x=1';
      final html = buildSigningPage(template, url);
      expect(html, contains('url: "https://www.signwell.com/embedded/sign/abc/?x=1"'));
      expect(html, isNot(contains('__SIGNWELL_SIGNING_URL__')));
    });

    test('escapes quotes so the URL cannot break out of the script', () {
      final html = buildSigningPage(template, "https://www.signwell.com/x');alert(1);//");
      expect(html, contains(r'''url: "https://www.signwell.com/x');alert(1);//"'''));
    });

    test('rejects non-https URLs', () {
      expect(() => buildSigningPage(template, 'javascript:alert(1)'), throwsArgumentError);
    });

    test('page loads SignWell embed library and posts to the bridge', () {
      expect(template, contains('https://static.signwell.com/assets/embedded.js'));
      expect(template, contains('window.$signWellChannelName'));
    });
  });

  group('SignWellEvent.parse', () {
    test('parses completed with document id', () {
      final e = SignWellEvent.parse('{"type":"completed","data":{"id":"doc_1","url":null}}');
      expect(e.type, SignWellEventType.completed);
      expect(e.documentId, 'doc_1');
    });
    test('parses declined reason', () {
      final e = SignWellEvent.parse('{"type":"declined","data":{"id":"d","declineReason":"Wrong price"}}');
      expect(e.declineReason, 'Wrong price');
    });
    test('tolerates junk', () {
      expect(SignWellEvent.parse('not json').type, SignWellEventType.unknown);
      expect(SignWellEvent.parse('{"type":"weird"}').type, SignWellEventType.unknown);
    });
  });

  testWidgets('home screen shows the form and reports backend errors', (tester) async {
    final api = BackendApi(
      baseUrl: 'http://backend.test',
      client: MockClient((req) async {
        expect(req.url.path, '/signing-sessions');
        expect(jsonDecode(req.body), {'name': 'Dana Demo', 'email': 'dana@example.com'});
        return http.Response('{"error":"SignWell error 401"}', 502);
      }),
    );
    await tester.pumpWidget(SignWellDemoApp(api: api));
    expect(find.text('Sample Service Agreement'), findsOneWidget);
    expect(find.text('Review and sign'), findsOneWidget);

    await tester.tap(find.text('Review and sign'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not start signing: SignWell error 401'), findsOneWidget);
  });

  testWidgets('validates the email before calling the backend', (tester) async {
    var called = false;
    final api = BackendApi(
      baseUrl: 'http://backend.test',
      client: MockClient((req) async {
        called = true;
        return http.Response('{}', 200);
      }),
    );
    await tester.pumpWidget(SignWellDemoApp(api: api));
    await tester.enterText(find.byType(TextFormField).last, 'not-an-email');
    await tester.tap(find.text('Review and sign'));
    await tester.pump();
    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(called, isFalse);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
