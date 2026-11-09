import 'package:flutter/foundation.dart';

/// A piece of information to request from an ID in Apple Wallet.
///
/// Display requests only show the information to the person checking the ID,
/// in a system sheet; the app never receives the values themselves.
@immutable
final class DisplayElement {
  const DisplayElement._(this.type) : minimumAge = null;

  /// Whether the holder is at least [minimumAge] years old.
  const DisplayElement.ageAtLeast(int this.minimumAge)
    : assert(minimumAge > 0, 'minimumAge must be positive'),
      type = 'ageAtLeast';

  /// The holder's given (first) name.
  static const givenName = DisplayElement._('givenName');

  /// The holder's family (last) name.
  static const familyName = DisplayElement._('familyName');

  /// The holder's full name. Requires iOS 27 or later.
  static const name = DisplayElement._('name');

  /// The holder's age in years.
  static const age = DisplayElement._('age');

  /// Identifier sent to the platform side.
  final String type;

  /// Threshold for [DisplayElement.ageAtLeast]; `null` for other elements.
  final int? minimumAge;

  /// Serializes this element for the method channel.
  Map<String, Object?> toMap() => {'type': type, 'age': ?minimumAge};

  @override
  bool operator ==(Object other) =>
      other is DisplayElement &&
      other.type == type &&
      other.minimumAge == minimumAge;

  @override
  int get hashCode => Object.hash(type, minimumAge);

  @override
  String toString() => minimumAge == null
      ? 'DisplayElement.$type'
      : 'DisplayElement.$type($minimumAge)';
}

/// Controls which buttons the system sheet shows once a document was read.
enum ValidationMode {
  /// A single button to perform one document request. This is the default.
  check,

  /// A button to perform several document requests in one session.
  checkMultiple,

  /// Buttons that let the person checking the ID approve or reject it.
  confirm,
}

/// How the person checking the ID responded to the system sheet.
enum ValidationOutcome {
  /// They approved the document.
  approved,

  /// They rejected the document.
  rejected,

  /// They closed the sheet without explicitly approving or rejecting.
  dismissed,
}

/// A kind of ID accepted by [WalletVerifierApi.displayDocument].
@immutable
final class DocumentType {
  const DocumentType._(this.type) : region = null;

  /// A national ID card issued by [region], an ISO 3166-1 region code such as `"JP"`.
  const DocumentType.nationalIDCard(String this.region)
    : type = 'nationalIDCard';

  /// A mobile driver's license.
  static const driversLicense = DocumentType._('driversLicense');

  /// A photo ID, such as a Digital ID in Apple Wallet.
  static const photoID = DocumentType._('photoID');

  /// Identifier sent to the platform side.
  final String type;

  /// Issuing region for [DocumentType.nationalIDCard]; `null` otherwise.
  final String? region;

  /// Serializes this document type for the method channel.
  Map<String, Object?> toMap() => {'type': type, 'region': ?region};

  @override
  bool operator ==(Object other) =>
      other is DocumentType && other.type == type && other.region == region;

  @override
  int get hashCode => Object.hash(type, region);

  @override
  String toString() =>
      region == null ? 'DocumentType.$type' : 'DocumentType.$type($region)';
}

/// Why a request failed.
enum WalletVerifierErrorCode {
  /// The person dismissed the reader before a document was read.
  cancelled,

  /// The app or device isn't allowed to read documents (check the entitlement).
  notAllowed,

  /// This device doesn't support the Verifier API.
  notSupported,

  /// The reader session expired. The plugin retries once before reporting this.
  sessionExpired,

  /// The network can't be reached.
  networkUnavailable,

  /// The reader service is unavailable.
  serviceUnavailable,

  /// The system is busy, for example with another request.
  systemBusy,

  /// The reader token isn't valid.
  invalidToken,

  /// The request isn't valid.
  invalidRequest,

  /// The response isn't valid.
  invalidResponse,

  /// The iOS version is too old for the requested feature.
  unsupportedOSVersion,

  /// National ID cards from the requested region aren't supported.
  unsupportedRegion,

  /// An element isn't available on this iOS version (for example [DisplayElement.name]).
  unsupportedElement,

  /// The plugin received arguments it couldn't understand.
  invalidArgument,

  /// Any other error.
  unknown;

  /// Parses a platform error code, falling back to [unknown].
  static WalletVerifierErrorCode fromCode(String code) =>
      values.firstWhere((value) => value.name == code, orElse: () => unknown);
}

/// Thrown when a Verifier API request fails.
class WalletVerifierException implements Exception {
  const WalletVerifierException(this.code, [this.message]);

  final WalletVerifierErrorCode code;
  final String? message;

  @override
  String toString() =>
      'WalletVerifierException(${code.name}'
      '${message == null ? '' : ', $message'})';
}
