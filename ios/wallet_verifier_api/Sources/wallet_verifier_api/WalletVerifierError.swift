import Flutter
import Foundation
import ProximityReader

/// Errors raised by the plugin itself (as opposed to the Verifier API).
///
/// Every case maps to a stable `code` string that the Dart side turns into a
/// `WalletVerifierErrorCode`. Keep both lists in sync.
enum WalletVerifierError: Error {
    case invalidArgument(String)
    case unsupportedOSVersion(required: String)
    case unsupportedRegion(String)
    case unsupportedElement(String, required: String)
    case reader(code: String, message: String)

    var code: String {
        switch self {
        case .invalidArgument: return "invalidArgument"
        case .unsupportedOSVersion: return "unsupportedOSVersion"
        case .unsupportedRegion: return "unsupportedRegion"
        case .unsupportedElement: return "unsupportedElement"
        case .reader(let code, _): return code
        }
    }

    var message: String {
        switch self {
        case .invalidArgument(let detail):
            return "Invalid arguments: \(detail)"
        case .unsupportedOSVersion(let required):
            return "iOS \(required) or later is required for this feature."
        case .unsupportedRegion(let region):
            return "National ID cards from region '\(region)' aren't supported."
        case .unsupportedElement(let element, let required):
            return "The '\(element)' element requires iOS \(required) or later."
        case .reader(_, let message):
            return message
        }
    }

    var flutterError: FlutterError {
        FlutterError(code: code, message: message, details: nil)
    }

    /// Converts any error thrown while talking to ProximityReader into a plugin error.
    static func from(_ error: Error) -> WalletVerifierError {
        if let error = error as? WalletVerifierError {
            return error
        }
        if #available(iOS 17.0, *), let error = error as? MobileDocumentReaderError {
            return .reader(code: code(for: error), message: error.localizedDescription)
        }
        return .reader(code: "unknown", message: error.localizedDescription)
    }

    @available(iOS 17.0, *)
    private static func code(for error: MobileDocumentReaderError) -> String {
        switch error {
        case .cancelled: return "cancelled"
        case .notAllowed: return "notAllowed"
        case .notSupported: return "notSupported"
        case .sessionExpired: return "sessionExpired"
        case .networkUnavailable: return "networkUnavailable"
        case .serviceUnavailable: return "serviceUnavailable"
        case .systemBusy: return "systemBusy"
        case .invalidToken: return "invalidToken"
        case .invalidRequest: return "invalidRequest"
        case .invalidResponse: return "invalidResponse"
        case .unknown: return "unknown"
        @unknown default: return "unknown"
        }
    }
}
