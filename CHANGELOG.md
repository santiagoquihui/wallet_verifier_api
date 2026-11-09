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

## 0.1.0
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
