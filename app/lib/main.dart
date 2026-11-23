import 'package:material_ui/material_ui.dart';

import 'src/backend_api.dart';
import 'src/signing_screen.dart';
import 'src/signwell_bridge.dart';

void main() => runApp(const SignWellDemoApp());

class SignWellDemoApp extends StatelessWidget {
  const SignWellDemoApp({super.key, this.api});

  /// Injectable for tests.
  final BackendApi? api;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SignWell Flutter demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF2BA3B8), useMaterial3: true),
      home: HomeScreen(api: api ?? BackendApi()),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.api});
  final BackendApi api;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(text: 'Dana Demo');
  final _email = TextEditingController(text: 'dana@example.com');
  bool _busy = false;
  String? _status;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _sign() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      // 1. Your backend creates the SignWell document and returns the URL.
      final session = await widget.api.createSigningSession(
        name: _name.text.trim(),
        email: _email.text.trim(),
      );
      if (!mounted) return;

      // 2. Show SignWell signing inside the app.
      final event = await Navigator.of(context).push<SignWellEvent>(
        MaterialPageRoute(builder: (_) => SigningScreen(signingUrl: session.signingUrl)),
      );

      // 3. Confirm with your backend. The in-app event drives the UI; the
      //    SignWell API / webhook is the source of truth.
      final String message;
      switch (event?.type) {
        case SignWellEventType.completed:
          final status = await widget.api.documentStatus(session.documentId);
          message = 'Signed. SignWell status: $status';
        case SignWellEventType.declined:
          final reason = event?.declineReason;
          message = reason == null ? 'Declined.' : 'Declined: $reason';
        case SignWellEventType.error:
          message = 'Something went wrong: ${event?.message ?? 'unknown error'}';
        default:
          message = 'Closed without signing.';
      }
      if (mounted) setState(() => _status = message);
    } on Exception catch (e) {
      if (mounted) setState(() => _status = 'Could not start signing: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('SignWell Flutter demo')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Sample Service Agreement', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Sign a demo agreement without leaving the app. The demo backend '
              'creates documents in SignWell test mode.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Form(
              key: _form,
              child: Column(
                children: [
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(
                        labelText: 'Signer name', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                        labelText: 'Signer email', border: OutlineInputBorder()),
                    validator: (v) =>
                        (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : _sign,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.draw_outlined),
              label: const Text('Review and sign'),
            ),
            if (_status != null) ...[
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_status!, key: const Key('status')),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
