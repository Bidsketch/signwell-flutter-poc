import 'dart:convert';

/// Name of the JavaScript channel the signing page posts events to.
const signWellChannelName = 'SignWellBridge';

/// Asset path of the HTML page that hosts SignWell's embed library.
const signWellPageAsset = 'assets/signwell_signing.html';

/// Origin the local signing page pretends to be served from. Use an https
/// domain you control, e.g. --dart-define=SIGNING_PAGE_BASE_URL=https://app.yourcompany.com/
/// Nothing is fetched from it; it only gives the page a real origin.
const signingPageBaseUrl = String.fromEnvironment(
  'SIGNING_PAGE_BASE_URL',
  defaultValue: 'https://example.com/',
);

/// Fills the signing URL into the HTML template.
///
/// The URL is JSON-encoded so quotes or other characters can't break out of
/// the JavaScript string.
String buildSigningPage(String template, String signingUrl) {
  final uri = Uri.tryParse(signingUrl);
  if (uri == null || uri.scheme != 'https') {
    throw ArgumentError.value(signingUrl, 'signingUrl', 'must be an https URL');
  }
  return template.replaceFirst('__SIGNWELL_SIGNING_URL__', jsonEncode(signingUrl));
}

enum SignWellEventType {
  iframeLoaded,
  documentLoaded,
  completed,
  declined,
  closed,
  error,
  unknown,
}

/// An event from SignWell's embed library, forwarded by the signing page.
class SignWellEvent {
  const SignWellEvent(this.type, [this.data = const {}]);

  final SignWellEventType type;
  final Map<String, dynamic> data;

  /// SignWell document ID, when the event includes one.
  String? get documentId => data['id'] as String?;

  /// The signer's comment when they decline.
  String? get declineReason => data['declineReason'] as String?;

  String? get message => data['message'] as String?;

  static SignWellEvent parse(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final type = SignWellEventType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => SignWellEventType.unknown,
      );
      final data = json['data'];
      return SignWellEvent(type, data is Map<String, dynamic> ? data : const {});
    } on FormatException {
      return const SignWellEvent(SignWellEventType.unknown);
    } on TypeError {
      return const SignWellEvent(SignWellEventType.unknown);
    }
  }
}
