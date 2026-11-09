import 'package:flutter/foundation.dart';

import 'mdl_models.dart';

/// Arguments for an Android mDL read from a QR code, sent over the method
/// channel.
@immutable
class MdlQrReadRequest {
  const MdlQrReadRequest({
    required this.qrContent,
    required this.elements,
    this.docType = mdlDocType,
    this.namespace = mdlNamespace,
    this.timeout = const Duration(seconds: 45),
    this.additionalTrustedRootsPem = const [],
    this.vical,
  });

  /// The scanned `mdoc:` URI.
  final String qrContent;
  final List<MdlElement> elements;
  final String docType;
  final String namespace;
  final Duration timeout;

  /// Extra IACA root certificates (PEM) to trust besides the bundled ones.
  final List<String> additionalTrustedRootsPem;

  /// A signed AAMVA VICAL (raw CBOR bytes) to trust in addition to the bundled
  /// roots. Its signature and signer chain are checked against the bundled
  /// AAMVA DTS root before use.
  final Uint8List? vical;

  Map<String, Object?> toMap() => {
    'qrContent': qrContent,
    'elements': [for (final e in elements) e.identifier],
    'docType': docType,
    'namespace': namespace,
    'timeoutMillis': timeout.inMilliseconds,
    'additionalTrustedRootsPem': additionalTrustedRootsPem,
    'vical': ?vical,
  };
}

/// Arguments for an Android mDL read by NFC tap, sent over the method channel.
@immutable
class MdlNfcReadRequest {
  const MdlNfcReadRequest({
    required this.elements,
    this.docType = mdlDocType,
    this.namespace = mdlNamespace,
    this.timeout = const Duration(seconds: 60),
    this.additionalTrustedRootsPem = const [],
    this.vical,
  });

  final List<MdlElement> elements;
  final String docType;
  final String namespace;

  /// Covers both waiting for the tap and the data transfer that follows.
  final Duration timeout;

  /// Extra IACA root certificates (PEM) to trust besides the bundled ones.
  final List<String> additionalTrustedRootsPem;

  /// A signed AAMVA VICAL (raw CBOR bytes); see [MdlQrReadRequest.vical].
  final Uint8List? vical;

  Map<String, Object?> toMap() => {
    'elements': [for (final e in elements) e.identifier],
    'docType': docType,
    'namespace': namespace,
    'timeoutMillis': timeout.inMilliseconds,
    'additionalTrustedRootsPem': additionalTrustedRootsPem,
    'vical': ?vical,
  };
}
