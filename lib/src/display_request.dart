import 'package:flutter/foundation.dart';

import 'models.dart';

/// Which ProximityReader request a [DisplayRequest] maps to.
enum DisplayDocument {
  /// `MobileDriversLicenseDisplayRequest` (iOS 17+).
  driversLicense,

  /// `MobileNationalIDCardDisplayRequest` (iOS 18+).
  nationalIDCard,

  /// `MobileDocumentDisplayRequest` (iOS 26+).
  anyOf,
}

/// A display request as passed to the platform implementation.
@immutable
class DisplayRequest {
  const DisplayRequest({
    required this.document,
    required this.elements,
    this.validationMode = ValidationMode.check,
    this.region,
    this.allowedDocumentTypes = const [],
  });

  final DisplayDocument document;
  final List<DisplayElement> elements;
  final ValidationMode validationMode;

  /// Issuing region, for [DisplayDocument.nationalIDCard].
  final String? region;

  /// Accepted document types, for [DisplayDocument.anyOf].
  final List<DocumentType> allowedDocumentTypes;

  /// Serializes this request for the method channel.
  Map<String, Object?> toMap() => {
    'document': document.name,
    'elements': [for (final element in elements) element.toMap()],
    'validationMode': validationMode.name,
    'region': ?region,
    if (document == DisplayDocument.anyOf)
      'allowedDocumentTypes': [
        for (final type in allowedDocumentTypes) type.toMap(),
      ],
  };
}
