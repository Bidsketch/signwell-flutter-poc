import 'dart:convert';
import 'dart:typed_data';

/// Builds the request body for POST /api/v1/documents using the bundled sample
/// PDF, with the fields placed on the signature block.
///
/// Field coordinates are in SignWell pixels: 96 per inch, measured from the
/// top-left corner of the page. PDF points are 72 per inch, so
/// pixels = points * 4 / 3. (US Letter = 816 x 1056 px.)
Map<String, dynamic> sampleDocumentRequest({
  required Uint8List pdfBytes,
  required String signerName,
  required String signerEmail,
  required bool testMode,
}) {
  return {
    'test_mode': testMode,
    'name': 'Sample Service Agreement',
    'embedded_signing': true,
    // Signing happens inside the app, so don't email the signer.
    'reminders': false,
    'files': [
      {'name': 'sample-agreement.pdf', 'file_base64': base64Encode(pdfBytes)},
    ],
    'recipients': [
      {'id': '1', 'name': signerName, 'email': signerEmail},
    ],
    'fields': [
      [
        {
          'type': 'signature',
          'recipient_id': '1',
          'page': 1,
          'x': 96,
          'y': 459,
          'width': 300,
          'height': 50,
          'required': true,
        },
        {
          'type': 'text',
          'recipient_id': '1',
          'page': 1,
          'x': 96,
          'y': 541,
          'width': 300,
          'height': 24,
          'required': true,
          'value': signerName,
        },
        {
          'type': 'date',
          'recipient_id': '1',
          'page': 1,
          'x': 96,
          'y': 621,
          'width': 160,
          'height': 24,
          'required': true,
          'lock_sign_date': true,
          'date_format': 'Month DD, YYYY',
        },
      ],
    ],
  };
}

/// Builds the request body for POST /api/v1/document_templates/documents.
/// [placeholderName] must match the recipient placeholder in your template.
Map<String, dynamic> templateDocumentRequest({
  required String templateId,
  required String placeholderName,
  required String signerName,
  required String signerEmail,
  required bool testMode,
}) {
  return {
    'test_mode': testMode,
    'template_id': templateId,
    'embedded_signing': true,
    'reminders': false,
    'recipients': [
      {
        'id': '1',
        'placeholder_name': placeholderName,
        'name': signerName,
        'email': signerEmail,
      },
    ],
  };
}
