## 0.0.1

- Initial release
- Verifier API `ageAtLeast` element added


## 0.0.2
- Fix extra `HANDLE_ERROR` in `verifyAge` result

## 0.0.3
- Add missing `MobileDriversLicenseElement`: `familyName`, `givenName` and `age`

## 0.0.4
- Prepare for public release

## 0.0.5
- Add README.md
- Refactor `MobileDriversLicenseElement` to another file

## 0.0.6
- Add basic `notSupported` error

## 0.0.7
- feat: Add `isSupported` method

## 0.0.8
- Support iOS 13.0+

## 0.1.0-beta.1
- **Swift Package Manager**: the iOS plugin is now a Swift package. The podspec
  remains as a fallback for apps that still use CocoaPods, and the example app
  no longer uses CocoaPods.
- **Breaking**: requires Flutter 3.44+ / Dart 3.10+ and an iOS 15.0+ deployment target.
- Requests now complete when the reader closes and return a `ValidationOutcome`
  (`approved`, `rejected`, `dismissed`). Errors are no longer ignored: they
  throw `WalletVerifierException` with a `WalletVerifierErrorCode`.
- Add `displayDriversLicense` with `ValidationMode` (`check`, `checkMultiple`, `confirm`).
- Add `displayNationalIDCard` and `isNationalIDCardRegionSupported` (iOS 18+).
- Add `displayDocument` with `DocumentType.driversLicense`, `photoID` and
  `nationalIDCard(region)` (iOS 26+).
- Add the `DisplayElement.name` element (iOS 27+).
- Add `prepare` with optional reader tokens and `readerInstanceIdentifier`.
- Add a privacy manifest.
- Deprecate `verifyAge` and `MobileDriversLicenseElement` in favor of
  `displayDriversLicense` and `DisplayElement`.

## Unreleased (feature/android-mdl-verifier)

- **Android preview**: ISO/IEC 18013-5 mDL reader built on OpenWallet Foundation
  Multipaz 0.102.0. Adds `verifyMdlFromQr`, `isAndroidReaderSupported`,
  `hasAndroidReaderPermissions`, `requestAndroidReaderPermissions`,
  `cancelMdlRead`, `MdlElement`, `MdlReadResult` and `MdocQrEngagement`.
  QR engagement + BLE transfer; verifies the issuer signature, element digests,
  validity and device authentication, then checks the issuer against bundled
  Arizona IACA roots and an optional signed AAMVA VICAL.
- **Android NFC engagement**: `verifyMdlFromNfc` reads an mDL by NFC tap using
  ISO 18013-5 static or negotiated handover (Apple Wallet, Google Wallet), with
  BLE (or NFC) data transfer. Adds `getNfcStatus`, `isNfcAvailable`,
  `openNfcSettings`, `MdlNfcStatus`, `MdlEngagement`, and
  `MdlReadResult.engagement` / `transport`.
- Add `WalletVerifierErrorCode.timedOut`, `transportFailed` and `nfcDisabled`.
- On Android, the iOS-only calls now answer instead of throwing
  `MissingPluginException`: `isSupported()` and
  `isNationalIDCardRegionSupported()` return `false`, display requests throw
  `notSupported`.
- The Android plugin declares `BLUETOOTH_SCAN` (neverForLocation),
  `BLUETOOTH_CONNECT`, `BLUETOOTH_ADVERTISE` and `NFC`, and needs `minSdk` 26
  (the reader itself runs on Android 12+).
