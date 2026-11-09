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
}
