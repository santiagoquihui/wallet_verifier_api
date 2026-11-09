import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:wallet_verifier_api/wallet_verifier_api.dart';

/// Android demo: scan a wallet's ISO 18013-5 QR code, read the license over
/// Bluetooth and show whether it verified.
class MdlReaderPage extends StatefulWidget {
  const MdlReaderPage({super.key});

  @override
  State<MdlReaderPage> createState() => _MdlReaderPageState();
}

class _MdlReaderPageState extends State<MdlReaderPage> {
  final _verifier = WalletVerifierApi();
  bool? _supported;
  bool _busy = false;
  String _status = 'Ask the guest to show the QR code in their wallet app.';
  MdlReadResult? _result;

  @override
  void initState() {
    super.initState();
    _verifier.isAndroidReaderSupported().then((value) {
      if (mounted) setState(() => _supported = value);
    });
  }

  @override
  void dispose() {
    if (_busy) _verifier.cancelMdlRead();
    super.dispose();
  }

  Future<void> _scanAndVerify() async {
    if (!await _verifier.requestAndroidReaderPermissions()) {
      setState(() => _status = 'Bluetooth permission is needed to read IDs.');
      return;
    }
    if (!mounted) return;
    final qr = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const _ScanPage()));
    if (qr == null || !mounted) return;
    setState(() {
      _busy = true;
      _result = null;
      _status = 'Connecting to the wallet… keep the phones close.';
    });
    try {
      final result = await _verifier.verifyMdlFromQr(qr);
      setState(() {
        _result = result;
        _status = result.isVerified ? 'Verified' : 'Not verified';
      });
    } on WalletVerifierException catch (e) {
      setState(
        () => _status =
            'Read failed: ${e.code.name}${e.message == null ? '' : '\n${e.message}'}',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('mDL reader (Android)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Reader supported: ${_supported ?? '…'}'),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy || _supported != true ? null : _scanAndVerify,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan wallet QR code'),
          ),
          if (_busy) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
            TextButton(
              onPressed: _verifier.cancelMdlRead,
              child: const Text('Cancel'),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            _status,
            key: const Key('mdl-status'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (result != null) _ResultCard(result: result),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final MdlReadResult result;

  @override
  Widget build(BuildContext context) {
    final verified = result.isVerified;
    final color = verified ? Colors.green : Colors.red;
    final portrait = result.portrait;
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(verified ? Icons.verified : Icons.gpp_bad, color: color),
                const SizedBox(width: 8),
                Text(
                  verified ? 'Verified' : 'Not verified',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (portrait != null)
              Center(
                child: Image.memory(
                  portrait,
                  height: 180,
                  errorBuilder: (_, _, _) =>
                      const Text('(portrait format not supported)'),
                ),
              ),
            _row(
              'Name',
              '${result.givenName ?? '?'} ${result.familyName ?? ''}',
            ),
            _row('Age 21+', switch (result.ageOver21) {
              true => 'YES',
              false => 'NO',
              null => 'not shared',
            }),
            _row('Birth date', result.birthDate ?? 'not shared'),
            _row('Expires', result.expiryDate ?? 'not shared'),
            _row('Issuing authority', result.issuingAuthority ?? 'not shared'),
            const Divider(),
            _row('Data intact', result.dataIntegrityVerified ? 'yes' : 'NO'),
            if (result.integrityError != null)
              _row('Integrity error', result.integrityError!),
            _row('Issuer trusted', result.issuerTrusted ? 'yes' : 'NO'),
            _row('Trusted root', result.issuerName ?? '—'),
            _row('Signer issuer', result.documentSignerIssuer ?? '—'),
            if (result.trustError != null) _row('Trust', result.trustError!),
            if (result.notReturned.isNotEmpty)
              _row('Not shared', result.notReturned.join(', ')),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

class _ScanPage extends StatefulWidget {
  const _ScanPage();

  @override
  State<_ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<_ScanPage> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && MdocQrEngagement.isEngagement(value)) {
        _done = true;
        Navigator.of(context).pop(value);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan wallet QR code')),
      body: MobileScanner(controller: _controller, onDetect: _onDetect),
    );
  }
}
