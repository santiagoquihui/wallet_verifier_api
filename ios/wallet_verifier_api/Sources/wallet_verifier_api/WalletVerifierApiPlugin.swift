import Flutter
import Foundation
import ProximityReader
import UIKit

public final class WalletVerifierApiPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "wallet_verifier_api", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(WalletVerifierApiPlugin(), channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isSupported":
            if #available(iOS 17.0, *) {
                result(DocumentReader.isSupported)
            } else {
                result(false)
            }

        case "isNationalIDCardRegionSupported":
            guard #available(iOS 18.0, *) else {
                result(false)
                return
            }
            do {
                let region = try DisplayRequestArguments.region((call.arguments as? [String: Any])?["region"])
                result(MobileNationalIDCardDisplayRequest.isSupportedRegion(Locale.Region(region)))
            } catch {
                result(WalletVerifierError.from(error).flutterError)
            }

        case "prepare":
            guard #available(iOS 17.0, *) else {
                result(Self.requiresIOS17)
                return
            }
            let token = (call.arguments as? [String: Any])?["readerToken"] as? String
            run(result) {
                try await DocumentReader.shared.prepare(readerToken: token)
                return nil
            }

        case "readerInstanceIdentifier":
            guard #available(iOS 17.0, *) else {
                result(Self.requiresIOS17)
                return
            }
            run(result) {
                try await DocumentReader.shared.readerInstanceIdentifier()
            }

        case "requestDisplay":
            let arguments: DisplayRequestArguments
            do {
                arguments = try DisplayRequestArguments(call.arguments)
            } catch {
                result(WalletVerifierError.from(error).flutterError)
                return
            }
            guard #available(iOS 17.0, *) else {
                result(Self.requiresIOS17)
                return
            }
            run(result) {
                try await DocumentReader.shared.display(arguments)
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private static var requiresIOS17: FlutterError {
        WalletVerifierError.unsupportedOSVersion(required: "17.0").flutterError
    }

    /// Runs `body` on the main actor and reports its value, or a
    /// `FlutterError`, back to Dart.
    private func run(
        _ result: @escaping FlutterResult,
        _ body: @escaping @MainActor () async throws -> Any?
    ) {
        Task { @MainActor in
            do {
                result(try await body())
            } catch {
                result(WalletVerifierError.from(error).flutterError)
            }
        }
    }
}
