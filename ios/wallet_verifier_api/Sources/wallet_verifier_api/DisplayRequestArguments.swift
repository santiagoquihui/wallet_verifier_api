import Foundation

/// Platform-agnostic description of a display request, decoded from the
/// method channel arguments before any ProximityReader type is touched.
struct DisplayRequestArguments {
    enum Element {
        case givenName
        case familyName
        case name
        case age
        case ageAtLeast(Int)
    }

    enum ValidationMode: String {
        case check
        case checkMultiple
        case confirm
    }

    enum DocumentType {
        case driversLicense
        case photoID
        case nationalIDCard(region: String)
    }

    enum Document {
        /// `MobileDriversLicenseDisplayRequest` (iOS 17+).
        case driversLicense
        /// `MobileNationalIDCardDisplayRequest` (iOS 18+).
        case nationalIDCard(region: String)
        /// `MobileDocumentDisplayRequest` (iOS 26+).
        case anyOf([DocumentType])
    }

    let document: Document
    let elements: [Element]
    let validationMode: ValidationMode

    init(_ arguments: Any?) throws {
        guard let args = arguments as? [String: Any] else {
            throw WalletVerifierError.invalidArgument("expected a map of arguments")
        }

        guard let rawElements = args["elements"] as? [[String: Any]] else {
            throw WalletVerifierError.invalidArgument("'elements' must be a list")
        }
        elements = try rawElements.map(Self.element)

        let rawMode = args["validationMode"] as? String ?? ValidationMode.check.rawValue
        guard let mode = ValidationMode(rawValue: rawMode) else {
            throw WalletVerifierError.invalidArgument("unknown validationMode '\(rawMode)'")
        }
        validationMode = mode

        switch args["document"] as? String {
        case "driversLicense", nil:
            document = .driversLicense
        case "nationalIDCard":
            document = .nationalIDCard(region: try Self.region(args["region"]))
        case "anyOf":
            let rawTypes = args["allowedDocumentTypes"] as? [[String: Any]] ?? []
            document = .anyOf(try rawTypes.map(Self.documentType))
        case let other?:
            throw WalletVerifierError.invalidArgument("unknown document '\(other)'")
        }
    }

    static func region(_ value: Any?) throws -> String {
        guard let region = value as? String, !region.isEmpty else {
            throw WalletVerifierError.invalidArgument("'region' must be a non-empty region code such as \"JP\"")
        }
        return region
    }

    private static func element(_ map: [String: Any]) throws -> Element {
        switch map["type"] as? String {
        case "givenName": return .givenName
        case "familyName": return .familyName
        case "name": return .name
        case "age": return .age
        case "ageAtLeast":
            guard let age = map["age"] as? Int, age > 0 else {
                throw WalletVerifierError.invalidArgument("'ageAtLeast' requires a positive 'age'")
            }
            return .ageAtLeast(age)
        case let other:
            throw WalletVerifierError.invalidArgument("unknown element '\(other ?? "nil")'")
        }
    }

    private static func documentType(_ map: [String: Any]) throws -> DocumentType {
        switch map["type"] as? String {
        case "driversLicense": return .driversLicense
        case "photoID": return .photoID
        case "nationalIDCard": return .nationalIDCard(region: try region(map["region"]))
        case let other:
            throw WalletVerifierError.invalidArgument("unknown document type '\(other ?? "nil")'")
        }
    }
}
