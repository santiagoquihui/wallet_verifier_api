import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:wallet_verifier_api/wallet_verifier_api.dart';

import 'mdl_reader_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _verifier = WalletVerifierApi();

  bool? _isSupported;
  ValidationMode _validationMode = ValidationMode.confirm;
  String _status = 'Tap a button to check an ID.';

  @override
  void initState() {
    super.initState();
    _verifier.isSupported().then((supported) {
      if (mounted) setState(() => _isSupported = supported);
    });
  }

  Future<void> _run(
    String label,
    Future<ValidationOutcome> Function() request,
  ) async {
    setState(() => _status = '$label…');
    try {
      final outcome = await request();
      setState(() => _status = '$label: ${outcome.name}');
    } on WalletVerifierException catch (e) {
      setState(
        () => _status =
            '$label failed: ${e.code.name}'
            '${e.message == null ? '' : '\n${e.message}'}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Apple's Verifier API is iOS-only; Android reads mDLs itself.
      return const MaterialApp(home: MdlReaderPage());
    }
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Verifier API Example')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Supported on this device: ${_isSupported ?? '…'}'),
            const SizedBox(height: 16),
            SegmentedButton<ValidationMode>(
              segments: [
                for (final mode in ValidationMode.values)
                  ButtonSegment(value: mode, label: Text(mode.name)),
              ],
              selected: {_validationMode},
              onSelectionChanged: (selection) =>
                  setState(() => _validationMode = selection.single),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _run(
                'Driver’s license, age 21+',
                () => _verifier.displayDriversLicense([
                  DisplayElement.givenName,
                  DisplayElement.familyName,
                  const DisplayElement.ageAtLeast(21),
                ], validationMode: _validationMode),
              ),
              child: const Text('Check driver’s license (iOS 17+)'),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: () => _run(
                'Japanese national ID card',
                () => _verifier.displayNationalIDCard(
                  region: 'JP',
                  elements: [DisplayElement.age],
                  validationMode: _validationMode,
                ),
              ),
              child: const Text('Check national ID card, JP (iOS 18+)'),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: () => _run(
                'Any ID, age 18+',
                () => _verifier.displayDocument(
                  [const DisplayElement.ageAtLeast(18)],
                  allowedDocumentTypes: [
                    DocumentType.driversLicense,
                    DocumentType.photoID,
                  ],
                  validationMode: _validationMode,
                ),
              ),
              child: const Text('Check license or photo ID (iOS 26+)'),
            ),
            const SizedBox(height: 24),
            Text(_status, key: const Key('status')),
          ],
        ),
      ),
    );
  }
}
