// Renders README screenshots of the native Flutter screens with real fonts.
// Run: flutter test tool/screenshot_test.dart --update-goldens
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signwell_flutter_poc/main.dart';
import 'package:signwell_flutter_poc/src/backend_api.dart';

Future<void> _loadFont(String family, List<String> files) async {
  final fonts = '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(Future.value(ByteData.sublistView(File('$fonts/$f').readAsBytesSync())));
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    await _loadFont('Roboto', ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']);
    await _loadFont('MaterialIcons', ['MaterialIcons-Regular.otf']);
  });

  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2160);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
  }

  testWidgets('home', (tester) async {
    await phone(tester);
    await tester.pumpWidget(SignWellDemoApp(api: BackendApi(baseUrl: 'http://x', client: MockClient((_) async => http.Response('{}', 500)))));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../../docs/screenshots/home.png'));
  });
}
