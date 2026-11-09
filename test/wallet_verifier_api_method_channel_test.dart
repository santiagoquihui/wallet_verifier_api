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
}
