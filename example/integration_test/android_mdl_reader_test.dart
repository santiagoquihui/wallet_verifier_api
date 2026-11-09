// Runs against the real Android plugin (emulator or device). No wallet is
// present, so a read with a synthetic engagement must fail cleanly (timeout or
// Bluetooth error), which exercises engagement parsing, key agreement setup,
// request building and the BLE transport without crashing.
//
// Grant Bluetooth permissions first, e.g.:
//   adb shell pm grant com.kiwis08.wallet_verifier_api_example android.permission.BLUETOOTH_SCAN
//   (and BLUETOOTH_CONNECT, BLUETOOTH_ADVERTISE)

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wallet_verifier_api/wallet_verifier_api.dart';

// DeviceEngagement (CBOR map) 1.0 with a random P-256 eDeviceKey and BLE peripheral
// server mode (UUID 9b7a3f2e-1c4d-4e5f-8a6b-7c8d9e0f1a2b).
const syntheticEngagement =
    'mdoc:owBjMS4wAYIB2BhYS6QBAiABIVggBZ9jFMJMZyAVxARtGFvUx05I54BQN99tqFMpyw2bTu0iWCADoYLAsOYjaS0PwFKTB6r9ryDY8gbL-62XDWGBTGNyWAKBgwIBowD1AfQKUJt6Py4cTU5fimt8jZ4PGis';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final plugin = WalletVerifierApi();
  final isAndroid = defaultTargetPlatform == TargetPlatform.android;

  testWidgets('reader support answers', (tester) async {
    expect(await plugin.isAndroidReaderSupported(), isA<bool>());
  }, skip: !isAndroid);

  testWidgets('read with no wallet fails cleanly', (tester) async {
    if (!await plugin.hasAndroidReaderPermissions()) {
      markTestSkipped('Bluetooth permissions not granted');
      return;
    }
    if (!await plugin.isAndroidReaderSupported()) {
      markTestSkipped('No Bluetooth LE on this device');
      return;
    }
    try {
      await plugin.verifyMdlFromQr(
        syntheticEngagement,
        timeout: const Duration(seconds: 8),
      );
      fail('A read without a wallet should not succeed');
    } on WalletVerifierException catch (e) {
      expect(
        e.code,
        anyOf(
          WalletVerifierErrorCode.timedOut,
          WalletVerifierErrorCode.transportFailed,
        ),
        reason: e.message,
      );
    }
  }, skip: !isAndroid);

  testWidgets('cancel ends a pending read', (tester) async {
    if (!await plugin.hasAndroidReaderPermissions()) {
      markTestSkipped('Bluetooth permissions not granted');
      return;
    }
    final read = plugin.verifyMdlFromQr(syntheticEngagement);
    await Future<void>.delayed(const Duration(seconds: 1));
    await plugin.cancelMdlRead();
    await expectLater(
      read,
      throwsA(
        isA<WalletVerifierException>().having(
          (e) => e.code,
          'code',
          anyOf(
            WalletVerifierErrorCode.cancelled,
            WalletVerifierErrorCode.transportFailed,
          ),
        ),
      ),
    );
  }, skip: !isAndroid);

  testWidgets('NFC read with no tap fails cleanly', (tester) async {
    if (!await plugin.hasAndroidReaderPermissions()) {
      markTestSkipped('Bluetooth permissions not granted');
      return;
    }
    final status = await plugin.getNfcStatus();
    try {
      await plugin.verifyMdlFromNfc(timeout: const Duration(seconds: 4));
      fail('A read without a tap should not succeed');
    } on WalletVerifierException catch (e) {
      // Reader mode turns on, nothing is tapped, the read times out and
      // reader mode turns off again.
      expect(e.code, switch (status) {
        MdlNfcStatus.enabled => WalletVerifierErrorCode.timedOut,
        MdlNfcStatus.disabled => WalletVerifierErrorCode.nfcDisabled,
        MdlNfcStatus.unsupported => WalletVerifierErrorCode.notSupported,
      }, reason: e.message);
    }
  }, skip: !isAndroid);

  testWidgets('cancel ends a pending NFC read', (tester) async {
    if (!await plugin.hasAndroidReaderPermissions() ||
        !await plugin.isNfcAvailable()) {
      markTestSkipped('Needs Bluetooth permissions and NFC turned on');
      return;
    }
    final read = plugin.verifyMdlFromNfc();
    await Future<void>.delayed(const Duration(seconds: 1));
    await plugin.cancelMdlRead();
    await expectLater(
      read,
      throwsA(
        isA<WalletVerifierException>().having(
          (e) => e.code,
          'code',
          WalletVerifierErrorCode.cancelled,
        ),
      ),
    );
  }, skip: !isAndroid);
}
