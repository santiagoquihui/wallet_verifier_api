import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:wallet_verifier_api/wallet_verifier_api.dart';

/// Android demo: start an ISO 18013-5 read from the wallet's QR code or by an
/// NFC tap, read the license (over Bluetooth, or NFC) and show whether it
/// verified.
class MdlReaderPage extends StatefulWidget {
  const MdlReaderPage({super.key});

  @override
  State<MdlReaderPage> createState() => _MdlReaderPageState();
}

class _MdlReaderPageState extends State<MdlReaderPage>
    with WidgetsBindingObserver {
  final _verifier = WalletVerifierApi();
  bool? _supported;
  MdlNfcStatus? _nfcStatus;
  bool _busy = false;
  bool _waitingForTap = false;
  String _status =
      'Ask the guest to show the QR code in their wallet app, or to tap '
      'their phone.';
  MdlReadResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _verifier.isAndroidReaderSupported().then((value) {
      if (mounted) setState(() => _supported = value);
    });
    _refreshNfcStatus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from the NFC settings screen.
    if (state == AppLifecycleState.resumed) _refreshNfcStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_busy) _verifier.cancelMdlRead();
    super.dispose();
  }

  Future<void> _refreshNfcStatus() async {
    final status = await _verifier.getNfcStatus();
    if (mounted) setState(() => _nfcStatus = status);
  }

  Future<void> _tapAndVerify() async {
    if (!await _verifier.requestAndroidReaderPermissions()) {
      setState(() => _status = 'Bluetooth permission is needed to read IDs.');
      return;
    }
    await _refreshNfcStatus();
    if (!mounted) return;
    if (_nfcStatus == MdlNfcStatus.disabled) {
      await _askToTurnOnNfc();
      return;
    }
    setState(() {
      _busy = true;
      _waitingForTap = true;
      _result = null;
      _status = 'Waiting for a phone…';
    });
    await _verify(() => _verifier.verifyMdlFromNfc());
  }

  Future<void> _askToTurnOnNfc() async {
    final open = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('NFC is off'),
        content: const Text(
          'Turn on NFC to read an ID by tapping a phone. You can still scan '
          'the QR code instead.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Open settings'),
          ),
        ],
      ),
    );
    if (open == true) await _verifier.openNfcSettings();
  }

  Future<void> _verify(Future<MdlReadResult> Function() read) async {
    try {
      final result = await read();
      if (!mounted) return;
      setState(() {
        _result = result;
        _status = result.isVerified ? 'Verified' : 'Not verified';
      });
    } on WalletVerifierException catch (e) {
      if (!mounted) return;
      setState(
        () => _status = switch (e.code) {
          WalletVerifierErrorCode.nfcDisabled =>
            'NFC is off. Turn it on and try again.',
          _ =>
            'Read failed: ${e.code.name}${e.message == null ? '' : '\n${e.message}'}',
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _waitingForTap = false;
        });
      }
    }
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
    await _verify(() => _verifier.verifyMdlFromQr(qr));
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
          Text('NFC: ${_nfcStatus?.name ?? '…'}'),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy || _supported != true ? null : _scanAndVerify,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan wallet QR code'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed:
                _busy ||
                    _supported != true ||
                    _nfcStatus == MdlNfcStatus.unsupported
                ? null
                : _tapAndVerify,
            icon: const Icon(Icons.nfc),
            label: const Text('Tap phone (NFC)'),
          ),
          if (_waitingForTap) const _TapPrompt(),
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

class _TapPrompt extends StatelessWidget {
  const _TapPrompt();

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('nfc-tap-prompt'),
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.contactless,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Hold the phone to the back of this device',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'On an iPhone, the ID appears automatically; the guest reviews '
              'and confirms with Face ID. Keep the phones close until this '
              'screen shows the result.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
            _row('Read via', _readVia(result)),
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

  static String _readVia(MdlReadResult result) {
    final engagement = switch (result.engagement) {
      MdlEngagement.qr => 'QR code',
      MdlEngagement.nfcStaticHandover => 'NFC tap (static handover)',
      MdlEngagement.nfcNegotiatedHandover => 'NFC tap (negotiated handover)',
      MdlEngagement.nfcV2Handover => 'NFC tap (NFCv2)',
      MdlEngagement.unknown => 'unknown',
    };
    final transport = result.transport;
    return transport == null ? engagement : '$engagement, data over $transport';
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
