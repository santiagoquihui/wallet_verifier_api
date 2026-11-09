import Foundation
import ProximityReader

/// Owns the `MobileDocumentReaderSession` and turns decoded arguments into
/// ProximityReader display requests.
///
/// APIs newer than the oldest supported Xcode are wrapped in `#if compiler`
/// checks so the plugin still builds with older SDKs:
/// - Swift 6.2 ships with Xcode 26 (iOS 26 SDK): `MobileDocumentDisplayRequest`.
/// - Swift 6.4 ships with Xcode 27 (iOS 27 SDK): the `name` element.
@available(iOS 17.0, *)
@MainActor
final class DocumentReader {
    static let shared = DocumentReader()

    private let reader = MobileDocumentReader()
    private var cachedSession: MobileDocumentReaderSession?
    /// Reader token from the last `prepare(readerToken:)`, reused when a session
    /// has to be prepared again so the brand stays visible in the system UI.
    private var readerToken: MobileDocumentReader.Token?

    nonisolated static var isSupported: Bool {
        MobileDocumentReader.isSupported
    }

    /// The identifier your server exchanges for a reader token. Requires network
    /// access. Apple asks you not to cache this value.
    func readerInstanceIdentifier() async throws -> String {
        try await reader.configuration.readerInstanceIdentifier
    }

    /// Prepares a reader session ahead of time so the first request is faster.
    ///
    /// Passing a reader token replaces the current session with one that shows
    /// your brand's name and logo in the system UI.
    func prepare(readerToken tokenString: String?) async throws {
        if let tokenString {
            readerToken = MobileDocumentReader.Token(tokenString)
            cachedSession = nil
        }
        _ = try await session()
    }

    /// Performs the request and returns the validation outcome's raw name.
    func display(_ arguments: DisplayRequestArguments) async throws -> String {
        switch arguments.document {
        case .driversLicense:
            let request = MobileDriversLicenseDisplayRequest(
                elements: try arguments.elements.map(Self.driversLicenseElement),
                options: .init(validationMode: Self.driversLicenseMode(arguments.validationMode))
            )
            return Self.outcome(try await perform(request).validationOutcome)

        case .nationalIDCard(let regionCode):
            guard #available(iOS 18.0, *) else {
                throw WalletVerifierError.unsupportedOSVersion(required: "18.0")
            }
            let region = Locale.Region(regionCode)
            guard MobileNationalIDCardDisplayRequest.isSupportedRegion(region) else {
                throw WalletVerifierError.unsupportedRegion(regionCode)
            }
            let request = MobileNationalIDCardDisplayRequest(
                region: region,
                elements: try arguments.elements.map(Self.nationalIDElement),
                options: .init(validationMode: Self.nationalIDMode(arguments.validationMode))
            )
            return Self.outcome(try await perform(request).validationOutcome)

        case .anyOf(let types):
            #if compiler(>=6.2)
            guard #available(iOS 26.0, *) else {
                throw WalletVerifierError.unsupportedOSVersion(required: "26.0")
            }
            let request = MobileDocumentDisplayRequest(
                elements: try arguments.elements.map(Self.documentElement),
                options: .init(
                    allowedDocumentTypes: types.map(Self.documentType),
                    validationMode: Self.documentMode(arguments.validationMode)
                )
            )
            return Self.outcome(try await perform(request).validationOutcome)
            #else
            _ = types
            throw WalletVerifierError.unsupportedOSVersion(required: "26.0")
            #endif
        }
    }

    // MARK: - Session handling

    private func session() async throws -> MobileDocumentReaderSession {
        if let cachedSession {
            return cachedSession
        }
        let session = try await reader.prepare(using: readerToken)
        cachedSession = session
        return session
    }

    private func perform<Request: MobileDocumentRequest>(_ request: Request) async throws -> Request.Response {
        guard Self.isSupported else {
            throw WalletVerifierError.reader(
                code: "notSupported",
                message: "This device doesn't support the Verifier API."
            )
        }
        do {
            return try await session().requestDocument(request)
        } catch MobileDocumentReaderError.sessionExpired {
            // Sessions expire after a while; prepare a fresh one and retry once.
            cachedSession = nil
            return try await session().requestDocument(request)
        }
    }

    // MARK: - Driver's license

    private static func driversLicenseElement(
        _ element: DisplayRequestArguments.Element
    ) throws -> MobileDriversLicenseDisplayRequest.Element {
        switch element {
        case .givenName: return .givenName
        case .familyName: return .familyName
        case .age: return .age
        case .ageAtLeast(let age): return .ageAtLeast(age)
        case .name:
            #if compiler(>=6.4)
            if #available(iOS 27.0, *) { return .name }
            #endif
            throw WalletVerifierError.unsupportedElement("name", required: "27.0")
        }
    }

    private static func driversLicenseMode(
        _ mode: DisplayRequestArguments.ValidationMode
    ) -> MobileDriversLicenseDisplayRequest.Options.ValidationMode {
        switch mode {
        case .check: return .check
        case .checkMultiple: return .checkMultiple
        case .confirm: return .confirm
        }
    }

    private static func outcome(_ outcome: MobileDriversLicenseDisplayRequest.Response.ValidationOutcome) -> String {
        switch outcome {
        case .approved: return "approved"
        case .rejected: return "rejected"
        case .dismissed: return "dismissed"
        @unknown default: return "dismissed"
        }
    }

    // MARK: - National ID card

    @available(iOS 18.0, *)
    private static func nationalIDElement(
        _ element: DisplayRequestArguments.Element
    ) throws -> MobileNationalIDCardDisplayRequest.Element {
        switch element {
        case .givenName: return .givenName
        case .familyName: return .familyName
        case .age: return .age
        case .ageAtLeast(let age): return .ageAtLeast(age)
        case .name:
            #if compiler(>=6.4)
            if #available(iOS 27.0, *) { return .name }
            #endif
            throw WalletVerifierError.unsupportedElement("name", required: "27.0")
        }
    }

    @available(iOS 18.0, *)
    private static func nationalIDMode(
        _ mode: DisplayRequestArguments.ValidationMode
    ) -> MobileNationalIDCardDisplayRequest.Options.ValidationMode {
        switch mode {
        case .check: return .check
        case .checkMultiple: return .checkMultiple
        case .confirm: return .confirm
        }
    }

    @available(iOS 18.0, *)
    private static func outcome(_ outcome: MobileNationalIDCardDisplayRequest.Response.ValidationOutcome) -> String {
        switch outcome {
        case .approved: return "approved"
        case .rejected: return "rejected"
        case .dismissed: return "dismissed"
        @unknown default: return "dismissed"
        }
    }

    // MARK: - Any supported document (iOS 26+)

    #if compiler(>=6.2)
    @available(iOS 26.0, *)
    private static func documentElement(
        _ element: DisplayRequestArguments.Element
    ) throws -> MobileDocumentDisplayRequest.Element {
        switch element {
        case .givenName: return .givenName
        case .familyName: return .familyName
        case .age: return .age
        case .ageAtLeast(let age): return .ageAtLeast(age)
        case .name:
            #if compiler(>=6.4)
            if #available(iOS 27.0, *) { return .name }
            #endif
            throw WalletVerifierError.unsupportedElement("name", required: "27.0")
        }
    }

    @available(iOS 26.0, *)
    private static func documentType(
        _ type: DisplayRequestArguments.DocumentType
    ) -> MobileDocumentDisplayRequest.Options.DocumentType {
        switch type {
        case .driversLicense: return .driversLicense
        case .photoID: return .photoID
        case .nationalIDCard(let region): return .nationalIDCard(region: Locale.Region(region))
        }
    }

    @available(iOS 26.0, *)
    private static func documentMode(
        _ mode: DisplayRequestArguments.ValidationMode
    ) -> MobileDocumentDisplayRequest.Options.ValidationMode {
        switch mode {
        case .check: return .check
        case .checkMultiple: return .checkMultiple
        case .confirm: return .confirm
        }
    }

    @available(iOS 26.0, *)
    private static func outcome(_ outcome: MobileDocumentDisplayRequest.Response.ValidationOutcome) -> String {
        switch outcome {
        case .approved: return "approved"
        case .rejected: return "rejected"
        case .dismissed: return "dismissed"
        @unknown default: return "dismissed"
        }
    }
    #endif
}
