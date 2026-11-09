import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_verifier_api/wallet_verifier_api.dart';
import 'package:wallet_verifier_api/wallet_verifier_api_platform_interface.dart';

// DeviceEngagement {0: "1.0", 1: [1, eDeviceKey], 2: [BLE peripheral server]}.
const syntheticEngagement =
    'mdoc:owBjMS4wAYIB2BhYS6QBAiABIVggBZ9jFMJMZyAVxARtGFvUx05I54BQN99tqFMpyw2bTu0iWCADoYLAsOYjaS0PwFKTB6r9ryDY8gbL-62XDWGBTGNyWAKBgwIBowD1AfQKUJt6Py4cTU5fimt8jZ4PGis';

void main() {
  group('MdocQrEngagement', () {
    String uri(List<int> bytes) =>
        'mdoc:${base64Url.encode(bytes).replaceAll('=', '')}';

    test('accepts an mdoc: URI whose payload is a CBOR map', () {
      // {0: "1.0"}: 0xa1 = map(1)
      final qr = uri([0xa1, 0x00, 0x63, 0x31, 0x2e, 0x30]);
      expect(MdocQrEngagement.isEngagement(qr), isTrue);
      expect(MdocQrEngagement.isEngagement('  $qr\n'), isTrue);
      expect(MdocQrEngagement.decode(qr), [0xa1, 0x00, 0x63, 0x31, 0x2e, 0x30]);
    });

    test('accepts a real-shaped DeviceEngagement', () {
      expect(MdocQrEngagement.isEngagement(syntheticEngagement), isTrue);
    });

    test('rejects other content', () {
      expect(MdocQrEngagement.isEngagement('https://example.com'), isFalse);
      expect(MdocQrEngagement.isEngagement('mdoc:'), isFalse);
      expect(MdocQrEngagement.isEngagement('mdoc:@@@'), isFalse);
      // A CBOR array (0x82) is not a DeviceEngagement map.
      expect(MdocQrEngagement.isEngagement(uri([0x82, 0x01, 0x02])), isFalse);
    });
  });

  group('MdlReadResult.fromMap', () {
    test('parses a verified result', () {
      final portrait = Uint8List.fromList([0xff, 0xd8, 0xff]);
      final result = MdlReadResult.fromMap({
        'docType': 'org.iso.18013.5.1.mDL',
        'elements': <Object?, Object?>{
          'given_name': 'ADA',
          'family_name': 'LOVELACE',
          'birth_date': '1990-01-31',
          'age_over_21': true,
          'portrait': portrait,
          'issuing_authority': 'Arizona MVD',
          'expiry_date': '2030-01-31',
        },
        'notReturned': <Object?>['document_number'],
        'dataIntegrityVerified': true,
        'issuerTrusted': true,
        'issuerName': 'Arizona Department of Transportation (GoogleIACA)',
        'signedAt': '2026-11-01T12:00:00Z',
        'validUntil': '2027-11-01T12:00:00Z',
      });
      expect(result.isVerified, isTrue);
      expect(result.givenName, 'ADA');
      expect(result.familyName, 'LOVELACE');
      expect(result.birthDate, '1990-01-31');
      expect(result.ageOver21, isTrue);
      expect(result.portrait, portrait);
      expect(result.issuingAuthority, 'Arizona MVD');
      expect(result.expiryDate, '2030-01-31');
      expect(result.notReturned, ['document_number']);
      expect(result.signedAt, DateTime.utc(2026, 11, 1, 12));
      expect(result.validUntil!.isUtc, isTrue);
      expect(result.validFrom, isNull);
    });

    test('untrusted issuer is not verified even with intact data', () {
      final result = MdlReadResult.fromMap({
        'elements': <Object?, Object?>{'age_over_21': true},
        'dataIntegrityVerified': true,
        'issuerTrusted': false,
        'trustError': 'Issuer is not in the trust list',
      });
      expect(result.isVerified, isFalse);
      expect(result.trustError, isNotNull);
    });

    test('missing fields default to unverified', () {
      final result = MdlReadResult.fromMap(const {});
      expect(result.isVerified, isFalse);
      expect(result.elements, isEmpty);
      expect(result.docType, mdlDocType);
    });
  });

  test('MdlQrReadRequest.toMap includes VICAL only when given', () {
    final vical = Uint8List.fromList([1, 2, 3]);
    final map = MdlQrReadRequest(
      qrContent: 'mdoc:x',
      elements: const [MdlElement.ageOver21],
      vical: vical,
      timeout: const Duration(seconds: 10),
      additionalTrustedRootsPem: const ['PEM'],
    ).toMap();
    expect(map['elements'], ['age_over_21']);
    expect(map['vical'], vical);
    expect(map['timeoutMillis'], 10000);
    expect(map['additionalTrustedRootsPem'], ['PEM']);
  });

  test('MdlReadResult engagement defaults to unknown', () {
    final result = MdlReadResult.fromMap(const {});
    expect(result.engagement, MdlEngagement.unknown);
    expect(result.engagement.isNfc, isFalse);
    expect(result.transport, isNull);
    expect(
      MdlReadResult.fromMap(const {'engagement': 'qr'}).engagement,
      MdlEngagement.qr,
    );
  });
}
