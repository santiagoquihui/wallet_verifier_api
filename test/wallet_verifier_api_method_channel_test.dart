import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_verifier_api/wallet_verifier_api.dart';
import 'package:wallet_verifier_api/wallet_verifier_api_method_channel.dart';
import 'package:wallet_verifier_api/wallet_verifier_api_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelWalletVerifierApi();
  const channel = MethodChannel('wallet_verifier_api');
  final calls = <MethodCall>[];
  Object? Function(MethodCall call) handler = (_) => null;

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return handler(call);
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('isSupported returns the platform value', () async {
    handler = (_) => true;
    expect(await platform.isSupported(), isTrue);
    expect(calls.single.method, 'isSupported');
  });

  test('isNationalIDCardRegionSupported sends the region', () async {
    handler = (_) => false;
    expect(await platform.isNationalIDCardRegionSupported('JP'), isFalse);
    expect(calls.single.arguments, {'region': 'JP'});
  });

  test('requestDisplay serializes a driver license request', () async {
    handler = (_) => 'approved';
    final outcome = await platform.requestDisplay(
      const DisplayRequest(
        document: DisplayDocument.driversLicense,
        elements: [DisplayElement.givenName, DisplayElement.ageAtLeast(21)],
        validationMode: ValidationMode.confirm,
      ),
    );

    expect(outcome, ValidationOutcome.approved);
    expect(calls.single.method, 'requestDisplay');
    expect(calls.single.arguments, {
      'document': 'driversLicense',
      'elements': [
        {'type': 'givenName'},
        {'type': 'ageAtLeast', 'age': 21},
      ],
      'validationMode': 'confirm',
    });
  });

  test('requestDisplay serializes allowed document types', () async {
    handler = (_) => 'rejected';
    final outcome = await platform.requestDisplay(
      const DisplayRequest(
        document: DisplayDocument.anyOf,
        elements: [DisplayElement.age],
        allowedDocumentTypes: [
          DocumentType.photoID,
          DocumentType.nationalIDCard('JP'),
        ],
      ),
    );

    expect(outcome, ValidationOutcome.rejected);
    expect(calls.single.arguments, {
      'document': 'anyOf',
      'elements': [
        {'type': 'age'},
      ],
      'validationMode': 'check',
      'allowedDocumentTypes': [
        {'type': 'photoID'},
        {'type': 'nationalIDCard', 'region': 'JP'},
      ],
    });
  });

  test('prepare sends the reader token only when given', () async {
    await platform.prepare();
    await platform.prepare(readerToken: 'abc');
    expect(calls.map((c) => c.arguments), [
      <String, Object?>{},
      {'readerToken': 'abc'},
    ]);
  });

  test('readerInstanceIdentifier returns the identifier', () async {
    handler = (_) => 'reader-1';
    expect(await platform.readerInstanceIdentifier(), 'reader-1');
  });

  test('platform errors become WalletVerifierException', () async {
    handler = (_) => throw PlatformException(code: 'cancelled', message: 'x');
    await expectLater(
      platform.requestDisplay(
        const DisplayRequest(
          document: DisplayDocument.driversLicense,
          elements: [DisplayElement.age],
        ),
      ),
      throwsA(
        isA<WalletVerifierException>().having(
          (e) => e.code,
          'code',
          WalletVerifierErrorCode.cancelled,
        ),
      ),
    );
  });

  test('unknown error codes map to unknown', () async {
    handler = (_) => throw PlatformException(code: 'somethingNew');
    await expectLater(
      platform.prepare(),
      throwsA(
        isA<WalletVerifierException>().having(
          (e) => e.code,
          'code',
          WalletVerifierErrorCode.unknown,
        ),
      ),
    );
  });

  test('readMdlFromQr sends the request and parses the result', () async {
    handler = (_) => <Object?, Object?>{
      'elements': <Object?, Object?>{'given_name': 'ADA'},
      'dataIntegrityVerified': true,
      'issuerTrusted': false,
    };
    final result = await platform.readMdlFromQr(
      const MdlQrReadRequest(
        qrContent: 'mdoc:oQBjMS4w',
        elements: [MdlElement.givenName],
      ),
    );
    expect(calls.single.method, 'readMdlFromQr');
    expect((calls.single.arguments as Map)['elements'], ['given_name']);
    expect(result.givenName, 'ADA');
    expect(result.isVerified, isFalse);
  });

  test('readMdlFromQr maps Android error codes', () async {
    handler = (_) => throw PlatformException(code: 'timedOut', message: 'x');
    await expectLater(
      platform.readMdlFromQr(
        const MdlQrReadRequest(
          qrContent: 'mdoc:oQBjMS4w',
          elements: [MdlElement.ageOver21],
        ),
      ),
      throwsA(
        isA<WalletVerifierException>().having(
          (e) => e.code,
          'code',
          WalletVerifierErrorCode.timedOut,
        ),
      ),
    );
  });

  test('readMdlFromNfc sends the request and parses the result', () async {
    handler = (_) => <Object?, Object?>{
      'elements': <Object?, Object?>{'age_over_21': true},
      'dataIntegrityVerified': true,
      'issuerTrusted': true,
      'engagement': 'nfcStaticHandover',
      'transport': 'NFC',
    };
    final result = await platform.readMdlFromNfc(
      const MdlNfcReadRequest(elements: [MdlElement.ageOver21]),
    );
    expect(calls.single.method, 'readMdlFromNfc');
    final args = calls.single.arguments as Map;
    expect(args['elements'], ['age_over_21']);
    expect(args.containsKey('qrContent'), isFalse);
    expect(result.engagement, MdlEngagement.nfcStaticHandover);
    expect(result.transport, 'NFC');
    expect(result.isVerified, isTrue);
  });

  test('readMdlFromNfc maps nfcDisabled', () async {
    handler = (_) => throw PlatformException(code: 'nfcDisabled');
    await expectLater(
      platform.readMdlFromNfc(
        const MdlNfcReadRequest(elements: [MdlElement.ageOver21]),
      ),
      throwsA(
        isA<WalletVerifierException>().having(
          (e) => e.code,
          'code',
          WalletVerifierErrorCode.nfcDisabled,
        ),
      ),
    );
  });

  test('getNfcStatus parses the status and defaults to unsupported', () async {
    handler = (_) => 'disabled';
    expect(await platform.getNfcStatus(), MdlNfcStatus.disabled);
    handler = (_) => 'enabled';
    expect(await platform.getNfcStatus(), MdlNfcStatus.enabled);
    handler = (_) => null;
    expect(await platform.getNfcStatus(), MdlNfcStatus.unsupported);
  });

  test('openNfcSettings returns the platform value', () async {
    handler = (_) => true;
    expect(await platform.openNfcSettings(), isTrue);
    expect(calls.last.method, 'openNfcSettings');
  });

  test(
    'startNfcHold returns the platform value, defaulting to false',
    () async {
      handler = (_) => true;
      expect(await platform.startNfcHold(), isTrue);
      expect(calls.last.method, 'startNfcHold');
      handler = (_) => null;
      expect(await platform.startNfcHold(), isFalse);
    },
  );

  test('stopNfcHold calls the platform', () async {
    await platform.stopNfcHold();
    expect(calls.single.method, 'stopNfcHold');
  });
}
