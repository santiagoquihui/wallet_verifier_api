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

## 0.1.0-beta.2

- **Android mDL reader (preview)**: Android devices can now read and verify
  ISO/IEC 18013-5 mobile driver's licenses themselves, built on OpenWallet
  Foundation Multipaz 0.102.0. Unlike the iOS display API, your app receives
  the data (name, birth date, age over 21, portrait, ...) and the result.
  - **QR engagement**: scan the holder's `mdoc:` QR code, then transfer over
    Bluetooth LE.
  - **NFC engagement**: tap phones; ISO 18013-5 static and negotiated handover
    (Apple Wallet, Google Wallet), then transfer over Bluetooth LE (or NFC).
  - **Verification**: issuer signature, element digests, validity window and
    device authentication, then the issuer is checked against the bundled
    Arizona IACA roots, extra roots you pass, or an optional signed AAMVA VICAL
    (its signature is checked against the bundled AAMVA root first).
  - Every element is requested with intent to retain = false.
- New Dart API (Android only; off Android these return `false` /
  `unsupported` or throw `notSupported`):
  - `verifyMdlFromQr`, `verifyMdlFromNfc`, `cancelMdlRead`
  - `isAndroidReaderSupported`, `hasAndroidReaderPermissions`,
    `requestAndroidReaderPermissions`
  - `getNfcStatus`, `isNfcAvailable`, `openNfcSettings`
  - `MdlElement`, `MdlReadResult` (with `engagement` and `transport`),
    `MdlEngagement`, `MdlNfcStatus`, `MdocQrEngagement`
  - `WalletVerifierErrorCode.timedOut`, `transportFailed` and `nfcDisabled`
- **Host apps on Android**: the plugin's manifest adds `BLUETOOTH_SCAN`
  (`neverForLocation`), `BLUETOOTH_CONNECT`, `BLUETOOTH_ADVERTISE` and `NFC`
  permissions, plus optional `bluetooth_le` and `nfc` features. It needs
  `minSdk` 26 (the reader runs on Android 12+) and ships R8 rules that keep
  Multipaz.
- On Android, the iOS-only calls now answer instead of throwing
  `MissingPluginException`: `isSupported()` and
  `isNationalIDCardRegionSupported()` return `false`, display requests throw
  `notSupported`. The iOS API is unchanged.
- Tested on real devices (Galaxy Z Flip6 as the reader): Arizona Mobile ID via
  QR and Apple Wallet via NFC tap (negotiated handover, BLE transfer) both
  returned verified data from a trusted Arizona issuer.

## 0.1.0-beta.3

- **Android: hold NFC for the whole verify screen.** New `startNfcHold()` /
  `stopNfcHold()`. While held, NFC reader mode stays on and tags are ignored
  unless a `verifyMdlFromNfc` read is running, so a wallet that is still
  touching the phone after a read (or touches it between reads, or during a QR
  read) no longer brings up Android's "New tag scanned" sheet. Reader mode is
  turned off when the activity pauses and back on when it resumes.
- Without a hold, behavior is unchanged: reader mode is on only while
  `verifyMdlFromNfc` waits for a tap.
