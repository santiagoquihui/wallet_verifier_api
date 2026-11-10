import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:wallet_verifier_api/wallet_verifier_api.dart';
import 'package:wallet_verifier_api/wallet_verifier_api_method_channel.dart';
import 'package:wallet_verifier_api/wallet_verifier_api_platform_interface.dart';

class FakeWalletVerifierApiPlatform
    with MockPlatformInterfaceMixin
    implements WalletVerifierApiPlatform {
  final requests = <DisplayRequest>[];
  ValidationOutcome outcome = ValidationOutcome.approved;

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<bool> isNationalIDCardRegionSupported(String region) async =>
      region == 'JP';

  String? preparedToken;

  @override
  Future<void> prepare({String? readerToken}) async {
    preparedToken = readerToken;
  }

  @override
  Future<String> readerInstanceIdentifier() async => 'reader-1';

  @override
  Future<ValidationOutcome> requestDisplay(DisplayRequest request) async {
    requests.add(request);
    return outcome;
  }

  final mdlRequests = <MdlQrReadRequest>[];

  @override
  Future<bool> isAndroidReaderSupported() async => true;

  @override
  Future<bool> hasAndroidReaderPermissions() async => true;

  @override
  Future<bool> requestAndroidReaderPermissions() async => true;

  @override
  Future<MdlReadResult> readMdlFromQr(MdlQrReadRequest request) async {
    mdlRequests.add(request);
    return MdlReadResult.fromMap(const {
      'dataIntegrityVerified': true,
      'issuerTrusted': true,
      'elements': {'age_over_21': true},
    });
  }

  final nfcRequests = <MdlNfcReadRequest>[];
  MdlNfcStatus nfcStatus = MdlNfcStatus.enabled;
  bool openedNfcSettings = false;

  @override
  Future<MdlReadResult> readMdlFromNfc(MdlNfcReadRequest request) async {
    nfcRequests.add(request);
    return MdlReadResult.fromMap(const {
      'dataIntegrityVerified': true,
      'issuerTrusted': true,
      'engagement': 'nfcNegotiatedHandover',
      'transport': 'Bluetooth',
      'elements': {'age_over_21': true},
    });
  }

  @override
  Future<MdlNfcStatus> getNfcStatus() async => nfcStatus;

  @override
  Future<bool> openNfcSettings() async => openedNfcSettings = true;

  bool cancelled = false;

  @override
  Future<void> cancelMdlRead() async => cancelled = true;

  int holds = 0;
  int releases = 0;

  @override
  Future<bool> startNfcHold() async {
    holds++;
    return true;
  }

  @override
  Future<void> stopNfcHold() async => releases++;
}

void main() {
  final initialPlatform = WalletVerifierApiPlatform.instance;
  late FakeWalletVerifierApiPlatform fake;
  final api = WalletVerifierApi();

  setUp(() {
    fake = FakeWalletVerifierApiPlatform();
    WalletVerifierApiPlatform.instance = fake;
  });

  test('$MethodChannelWalletVerifierApi is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelWalletVerifierApi>());
  });

  test('displayDriversLicense returns the outcome', () async {
    fake.outcome = ValidationOutcome.dismissed;
    final outcome = await api.displayDriversLicense([
      DisplayElement.name,
      const DisplayElement.ageAtLeast(18),
    ], validationMode: ValidationMode.checkMultiple);

    expect(outcome, ValidationOutcome.dismissed);
    final request = fake.requests.single;
    expect(request.document, DisplayDocument.driversLicense);
    expect(request.elements, [
      DisplayElement.name,
      const DisplayElement.ageAtLeast(18),
    ]);
    expect(request.validationMode, ValidationMode.checkMultiple);
  });

  test('displayNationalIDCard passes the region', () async {
    await api.displayNationalIDCard(
      region: 'JP',
      elements: [DisplayElement.age],
    );
    expect(fake.requests.single.document, DisplayDocument.nationalIDCard);
    expect(fake.requests.single.region, 'JP');
    expect(await api.isNationalIDCardRegionSupported('JP'), isTrue);
  });

  test('displayDocument rejects empty or duplicate document types', () {
    expect(
      () => api.displayDocument([DisplayElement.age], allowedDocumentTypes: []),
      throwsArgumentError,
    );
    expect(
      () => api.displayDocument(
        [DisplayElement.age],
        allowedDocumentTypes: [
          const DocumentType.nationalIDCard('JP'),
          const DocumentType.nationalIDCard('JP'),
        ],
      ),
      throwsArgumentError,
    );
    expect(fake.requests, isEmpty);
  });

  test('displayDocument forwards allowed document types', () async {
    await api.displayDocument(
      [DisplayElement.givenName],
      allowedDocumentTypes: [DocumentType.driversLicense, DocumentType.photoID],
    );
    expect(fake.requests.single.document, DisplayDocument.anyOf);
    expect(fake.requests.single.allowedDocumentTypes, [
      DocumentType.driversLicense,
      DocumentType.photoID,
    ]);
  });

  test('prepare forwards the reader token', () async {
    await api.prepare(readerToken: 'token');
    expect(fake.preparedToken, 'token');
    expect(await api.readerInstanceIdentifier(), 'reader-1');
  });

  group('deprecated verifyAge', () {
    test('maps legacy elements', () async {
      // ignore: deprecated_member_use_from_same_package
      await api.verifyAge([
        // ignore: deprecated_member_use_from_same_package
        MobileDriversLicenseElement.givenName,
        // ignore: deprecated_member_use_from_same_package
        MobileDriversLicenseElement.ageAtLeast,
      ], age: 21);
      expect(fake.requests.single.elements, [
        DisplayElement.givenName,
        const DisplayElement.ageAtLeast(21),
      ]);
    });

    test('requires age with ageAtLeast', () {
      expect(
        // ignore: deprecated_member_use_from_same_package
        () => api.verifyAge([MobileDriversLicenseElement.ageAtLeast]),
        throwsArgumentError,
      );
    });
  });

  group('Android mDL reader', () {
    // "mdoc:" + base64url of {0: "1.0"} (a CBOR map, like a DeviceEngagement).
    const qr = 'mdoc:oQBjMS4w';

    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('is unavailable off Android without calling the platform', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(await api.isAndroidReaderSupported(), isFalse);
      await expectLater(
        api.verifyMdlFromQr(qr),
        throwsA(
          isA<WalletVerifierException>().having(
            (e) => e.code,
            'code',
            WalletVerifierErrorCode.notSupported,
          ),
        ),
      );
      expect(fake.mdlRequests, isEmpty);
    });

    test('rejects QR codes that are not mdoc engagements', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await expectLater(
        api.verifyMdlFromQr('https://example.com'),
        throwsA(
          isA<WalletVerifierException>().having(
            (e) => e.code,
            'code',
            WalletVerifierErrorCode.invalidArgument,
          ),
        ),
      );
      expect(fake.mdlRequests, isEmpty);
    });

    test('sends the door-check elements by default', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final result = await api.verifyMdlFromQr(qr);
      expect(result.isVerified, isTrue);
      expect(result.ageOver21, isTrue);
      final map = fake.mdlRequests.single.toMap();
      expect(map['qrContent'], qr);
      expect(map['elements'], [
        'given_name',
        'family_name',
        'birth_date',
        'age_over_21',
        'portrait',
        'issuing_authority',
        'expiry_date',
      ]);
      expect(map['docType'], 'org.iso.18013.5.1.mDL');
      expect(map['namespace'], 'org.iso.18013.5.1');
      expect(map['timeoutMillis'], 45000);
      expect(map.containsKey('vical'), isFalse);
    });

    test(
      'NFC is unavailable off Android without calling the platform',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        expect(await api.getNfcStatus(), MdlNfcStatus.unsupported);
        expect(await api.isNfcAvailable(), isFalse);
        expect(await api.openNfcSettings(), isFalse);
        await expectLater(
          api.verifyMdlFromNfc(),
          throwsA(
            isA<WalletVerifierException>().having(
              (e) => e.code,
              'code',
              WalletVerifierErrorCode.notSupported,
            ),
          ),
        );
        expect(fake.nfcRequests, isEmpty);
        expect(fake.openedNfcSettings, isFalse);
      },
    );

    test('isNfcAvailable follows the NFC status on Android', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(await api.isNfcAvailable(), isTrue);
      fake.nfcStatus = MdlNfcStatus.disabled;
      expect(await api.getNfcStatus(), MdlNfcStatus.disabled);
      expect(await api.isNfcAvailable(), isFalse);
      expect(await api.openNfcSettings(), isTrue);
    });

    test('verifyMdlFromNfc sends the door-check elements by default', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final result = await api.verifyMdlFromNfc();
      expect(result.isVerified, isTrue);
      expect(result.engagement, MdlEngagement.nfcNegotiatedHandover);
      expect(result.engagement.isNfc, isTrue);
      expect(result.transport, 'Bluetooth');
      final map = fake.nfcRequests.single.toMap();
      expect(map.containsKey('qrContent'), isFalse);
      expect(map['elements'], hasLength(MdlElement.doorCheck.length));
      expect(map['timeoutMillis'], 60000);
      expect(fake.mdlRequests, isEmpty);
    });

    test('verifyMdlFromNfc rejects an empty element list', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(() => api.verifyMdlFromNfc(elements: []), throwsArgumentError);
    });

    test('cancelMdlRead forwards on Android', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await api.cancelMdlRead();
      expect(fake.cancelled, isTrue);
    });

    test('NFC hold forwards on Android', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(await api.startNfcHold(), isTrue);
      await api.stopNfcHold();
      expect(fake.holds, 1);
      expect(fake.releases, 1);
    });

    test('NFC hold is a no-op off Android', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(await api.startNfcHold(), isFalse);
      await api.stopNfcHold();
      expect(fake.holds, 0);
      expect(fake.releases, 0);
    });
  });
}
