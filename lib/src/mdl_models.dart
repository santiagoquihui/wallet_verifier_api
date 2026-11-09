import 'dart:convert';

import 'package:flutter/foundation.dart';

/// ISO/IEC 18013-5 mobile driver's license (mDL) document type.
const String mdlDocType = 'org.iso.18013.5.1.mDL';

/// ISO/IEC 18013-5 mDL namespace.
const String mdlNamespace = 'org.iso.18013.5.1';

/// A data element to request from a mobile driver's license (Android reader).
///
/// Unlike the iOS display API, the Android reader returns the values to the app.
@immutable
final class MdlElement {
  /// An element of the [mdlNamespace] by its ISO 18013-5 identifier.
  const MdlElement(this.identifier);

  /// ISO 18013-5 data element identifier, for example `given_name`.
  final String identifier;

  static const givenName = MdlElement('given_name');
  static const familyName = MdlElement('family_name');
  static const birthDate = MdlElement('birth_date');
  static const ageOver18 = MdlElement('age_over_18');
  static const ageOver21 = MdlElement('age_over_21');
  static const portrait = MdlElement('portrait');
  static const issuingAuthority = MdlElement('issuing_authority');
  static const issuingCountry = MdlElement('issuing_country');
  static const expiryDate = MdlElement('expiry_date');
  static const documentNumber = MdlElement('document_number');

  /// What a door check needs: name, birth date, 21+, photo, issuer and expiry.
  static const doorCheck = <MdlElement>[
    givenName,
    familyName,
    birthDate,
    ageOver21,
    portrait,
    issuingAuthority,
    expiryDate,
  ];

  @override
  bool operator ==(Object other) =>
      other is MdlElement && other.identifier == identifier;

  @override
  int get hashCode => identifier.hashCode;

  @override
  String toString() => 'MdlElement($identifier)';
}

/// Helpers for ISO 18013-5 QR device engagement (`mdoc:` URIs).
abstract final class MdocQrEngagement {
  static const prefix = 'mdoc:';

  /// Whether [content] looks like an ISO 18013-5 engagement QR code.
  ///
  /// Checks the `mdoc:` prefix, base64url payload and that the payload starts
  /// with a CBOR map (DeviceEngagement, ISO 18013-5 8.2.1.1). Use it to ignore
  /// unrelated QR codes before starting a Bluetooth session.
  static bool isEngagement(String content) {
    final bytes = decode(content);
    if (bytes == null || bytes.isEmpty) return false;
    // CBOR major type 5 (map) is 0xa0..0xbf.
    return bytes.first >= 0xa0 && bytes.first <= 0xbf;
  }

  /// Decodes the DeviceEngagement bytes from an `mdoc:` URI, or `null`.
  static Uint8List? decode(String content) {
    final trimmed = content.trim();
    if (!trimmed.startsWith(prefix)) return null;
    var payload = trimmed.substring(prefix.length);
    if (payload.isEmpty) return null;
    payload = payload.padRight((payload.length + 3) ~/ 4 * 4, '=');
    try {
      return base64Url.decode(payload);
    } on FormatException {
      return null;
    }
  }
}

/// Result of reading a mobile driver's license on Android.
@immutable
class MdlReadResult {
  const MdlReadResult({
    required this.docType,
    required this.elements,
    required this.notReturned,
    required this.dataIntegrityVerified,
    required this.issuerTrusted,
    this.issuerName,
    this.documentSignerSubject,
    this.documentSignerIssuer,
    this.signedAt,
    this.validFrom,
    this.validUntil,
    this.integrityError,
    this.trustError,
  });

  /// Parses the map sent by the Android plugin.
  factory MdlReadResult.fromMap(Map<Object?, Object?> map) {
    final rawElements = map['elements'] as Map<Object?, Object?>? ?? const {};
    return MdlReadResult(
      docType: map['docType'] as String? ?? mdlDocType,
      elements: {
        for (final entry in rawElements.entries)
          entry.key.toString(): entry.value,
      },
      notReturned: [
        for (final e in map['notReturned'] as List<Object?>? ?? const [])
          e.toString(),
      ],
      dataIntegrityVerified: map['dataIntegrityVerified'] as bool? ?? false,
      issuerTrusted: map['issuerTrusted'] as bool? ?? false,
      issuerName: map['issuerName'] as String?,
      documentSignerSubject: map['documentSignerSubject'] as String?,
      documentSignerIssuer: map['documentSignerIssuer'] as String?,
      signedAt: _parseDate(map['signedAt']),
      validFrom: _parseDate(map['validFrom']),
      validUntil: _parseDate(map['validUntil']),
      integrityError: map['integrityError'] as String?,
      trustError: map['trustError'] as String?,
    );
  }

  final String docType;

  /// Returned data elements by ISO 18013-5 identifier. Values are `String`,
  /// `bool`, `int`, `double`, `Uint8List` (e.g. `portrait`), `List` or `Map`.
  final Map<String, Object?> elements;

  /// Requested elements the wallet didn't return (the holder may decline some).
  final List<String> notReturned;

  /// The issuer's signature over the data, the per-element digests, the
  /// validity window and the holder's device authentication all checked out.
  final bool dataIntegrityVerified;

  /// The document signer chains to a trusted issuer root (IACA).
  final bool issuerTrusted;

  /// Display name of the trusted root that matched, if any.
  final String? issuerName;
  final String? documentSignerSubject;
  final String? documentSignerIssuer;
  final DateTime? signedAt;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final String? integrityError;
  final String? trustError;

  /// Both checks passed: the data is authentic and from a trusted issuer.
  bool get isVerified => dataIntegrityVerified && issuerTrusted;

  String? get givenName => elements['given_name'] as String?;
  String? get familyName => elements['family_name'] as String?;
  String? get birthDate => elements['birth_date'] as String?;
  bool? get ageOver21 => elements['age_over_21'] as bool?;
  bool? get ageOver18 => elements['age_over_18'] as bool?;
  Uint8List? get portrait => elements['portrait'] as Uint8List?;
  String? get issuingAuthority => elements['issuing_authority'] as String?;
  String? get expiryDate => elements['expiry_date'] as String?;

  static DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}
