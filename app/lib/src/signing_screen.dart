import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'signwell_bridge.dart';

/// Shows SignWell embedded signing in a WebView and returns the final
/// [SignWellEvent] (completed, declined, closed or error) when it's done.
///
/// Usage:
/// ```dart
/// final result = await Navigator.of(context).push<SignWellEvent>(
///   MaterialPageRoute(builder: (_) => SigningScreen(signingUrl: url)));
/// ```
class SigningScreen extends StatefulWidget {
  const SigningScreen({super.key, required this.signingUrl, this.title = 'Sign document'});

  /// The `embedded_signing_url` your backend got from the SignWell API.
  final String signingUrl;
  final String title;

  @override
  State<SigningScreen> createState() => _SigningScreenState();
}

class _SigningScreenState extends State<SigningScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..addJavaScriptChannel(signWellChannelName, onMessageReceived: (m) {
        _onEvent(SignWellEvent.parse(m.message));
      })
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: _onNavigationRequest,
      ));
    _loadPage();
  }

  Future<void> _loadPage() async {
    final template = await rootBundle.loadString(signWellPageAsset);
    final html = buildSigningPage(template, widget.signingUrl);
    // The page itself is local; SignWell's library and signing iFrame load
    // from signwell.com over HTTPS.
    //
    // The base URL matters: with no base URL the page gets an opaque
    // "about:blank" origin, and in our testing the SignWell iFrame then
    // loaded but rendered blank. An https base URL fixes it.
    await _controller.loadHtmlString(html, baseUrl: signingPageBaseUrl);
  }

  /// Keeps the top-level page on our local HTML. The SignWell iFrame can
  /// navigate freely inside itself; anything else that tries to take over the
  /// WebView (for example a link in the document) opens in the browser.
  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    final isLocalPage = uri == null || uri.scheme == 'about' || uri.scheme == 'data';
    if (!request.isMainFrame || isLocalPage) return NavigationDecision.navigate;
    if (uri.scheme == 'https' || uri.scheme == 'http') {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return NavigationDecision.prevent;
  }

  void _onEvent(SignWellEvent event) {
    switch (event.type) {
      case SignWellEventType.iframeLoaded:
      case SignWellEventType.documentLoaded:
        if (mounted && _loading) setState(() => _loading = false);
      case SignWellEventType.completed:
      case SignWellEventType.declined:
      case SignWellEventType.closed:
      case SignWellEventType.error:
        _finish(event);
      case SignWellEventType.unknown:
        break;
    }
  }

  void _finish(SignWellEvent event) {
    if (_finished || !mounted) return;
    _finished = true;
    Navigator.of(context).pop(event);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close',
          onPressed: () => _finish(const SignWellEvent(SignWellEventType.closed)),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_loading) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}
