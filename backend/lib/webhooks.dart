import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Verifies a SignWell webhook event.
///
/// SignWell signs `"<event.type>@<event.time>"` with HMAC-SHA256, keyed by the
/// webhook ID (returned when you create the webhook, or from GET /api/v1/hooks).
/// See https://developers.signwell.com/reference/event-hash-verification
///
/// The hash covers only the type and time, not the document data, so after a
/// valid event re-fetch the document from the API instead of trusting the body.
bool verifySignWellEvent(Map<String, dynamic> payload, String webhookId) {
  final event = payload['event'];
  if (event is! Map) return false;
  final type = event['type'];
  final time = event['time'];
  final hash = event['hash'];
  if (type == null || time == null || hash is! String) return false;
  final expected = Hmac(sha256, utf8.encode(webhookId))
      .convert(utf8.encode('$type@$time'))
      .toString();
  return _constantTimeEquals(expected, hash);
}

bool _constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}
