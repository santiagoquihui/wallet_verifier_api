# wallet_verifier_api

A Flutter wrapper around Apple's [Verifier API](https://developer.apple.com/wallet/id-verifier/)
(the ProximityReader framework). It lets an iPhone check IDs held in Apple Wallet
in person, using tap-to-present.

The plugin supports **display requests**. The system shows the requested
information (name, age, "age 21+", and so on) to the person checking the ID in
a secure sheet. Your app never receives the values. It only gets the
verifier's decision: approved, rejected, or dismissed.

On **Android** (preview), the plugin is an ISO/IEC 18013-5 reader instead: it
reads a mobile driver's license from the holder's wallet by QR code or NFC tap
(Apple Wallet, Google Wallet, Samsung Wallet, state wallet apps), verifies it
and returns the data to your app. See
[Android: read and verify mobile driver's licenses](#android-read-and-verify-mobile-drivers-licenses-preview).

| Feature | iOS |
| --- | --- |
| Mobile driver's licenses (`displayDriversLicense`) | 17.0+ |
| Validation modes and outcomes (`check`, `checkMultiple`, `confirm`) | 17.0+ |
| National ID cards by region (`displayNationalIDCard`) | 18.0+ |
| Any of several document types, including photo IDs (`displayDocument`) | 26.0+ |
| Full name element (`DisplayElement.name`) | 27.0+ |

## Requirements

- Flutter 3.44 or later (Dart 3.10 or later)
- iOS 15.0 or later deployment target. Calls on older iOS versions fail with
  `WalletVerifierErrorCode.unsupportedOSVersion`, and `isSupported()` returns `false`.
- The Verifier API capability (entitlement
  `com.apple.developer.proximity-reader.identity.display`) on your app target.
  Add it in Xcode under **Signing & Capabilities**, which writes this to your
  `Runner.entitlements`:

  ```xml
  <key>com.apple.developer.proximity-reader.identity.display</key>
  <true/>
  ```

The plugin supports Swift Package Manager and still ships a podspec for apps
that use CocoaPods.

## Usage

```yaml
dependencies:
  wallet_verifier_api: ^0.1.0-beta.1
```

```dart
import 'package:wallet_verifier_api/wallet_verifier_api.dart';

final verifier = WalletVerifierApi();

if (await verifier.isSupported()) {
  // Optional: prepare the reader ahead of time so the sheet opens faster.
  await verifier.prepare();

  try {
    final outcome = await verifier.displayDriversLicense(
      [
        DisplayElement.givenName,
        DisplayElement.familyName,
        const DisplayElement.ageAtLeast(21),
      ],
      validationMode: ValidationMode.confirm,
    );

    switch (outcome) {
      case ValidationOutcome.approved:
        // The verifier approved the ID.
        break;
      case ValidationOutcome.rejected:
      case ValidationOutcome.dismissed:
        break;
    }
  } on WalletVerifierException catch (e) {
    if (e.code == WalletVerifierErrorCode.cancelled) {
      // The reader was closed before an ID was presented.
    }
  }
}
```

### National ID cards (iOS 18+)

```dart
if (await verifier.isNationalIDCardRegionSupported('JP')) {
  await verifier.displayNationalIDCard(
    region: 'JP',
    elements: [const DisplayElement.ageAtLeast(18)],
  );
}
```

### Accept several kinds of ID (iOS 26+)

```dart
await verifier.displayDocument(
  [DisplayElement.name, DisplayElement.age],
  allowedDocumentTypes: [
    DocumentType.driversLicense,
    DocumentType.photoID,
    const DocumentType.nationalIDCard('JP'),
  ],
);
```

`allowedDocumentTypes` must be non-empty and free of duplicates.

### Show your brand in the system UI

Pass a reader token from your server to `prepare` to show your brand's name and
logo in the sheet. Your server creates the token from the reader instance
identifier; see Apple's
[Generating reader tokens for the Verifier API](https://developer.apple.com/documentation/proximityreader/generating-reader-tokens-for-the-verifier-api).

```dart
final identifier = await verifier.readerInstanceIdentifier(); // don't cache
final token = await myServer.fetchReaderToken(identifier);
await verifier.prepare(readerToken: token);
```

The plugin reuses the token for later requests. A token stays valid for 48
hours. After that, requests throw `WalletVerifierErrorCode.sessionExpired`, so
fetch a new token and call `prepare` again.

### Validation modes

| Mode | Sheet behavior |
| --- | --- |
| `ValidationMode.check` (default) | A button to perform a single document request. |
| `ValidationMode.checkMultiple` | A button to perform several document requests in one session. |
| `ValidationMode.confirm` | Buttons for the verifier to approve or reject the document. |

### Errors

Failed requests throw a `WalletVerifierException`. Its `code` is a
`WalletVerifierErrorCode`, which covers the Verifier API's errors
(`cancelled`, `notAllowed`, `notSupported`, `systemBusy`, and others) plus
plugin-specific ones (`unsupportedOSVersion`, `unsupportedRegion`,
`unsupportedElement`, `invalidArgument`).

## Android: read and verify mobile driver's licenses (preview)

Apple's Verifier API only exists on iOS. On Android the plugin reads ISO/IEC
18013-5 mobile driver's licenses itself, using
[Multipaz](https://github.com/openwallet-foundation/multipaz) (Apache-2.0).
Unlike the iOS display API, **your app receives the data** (name, birth date,
age over 21, portrait, ...) plus the verification result, and you build the UI.

Two ways to start a read:

- **QR**: the holder shows an `mdoc:` QR code in their wallet app, you scan it
  (with any scanner, e.g. `mobile_scanner`) and call `verifyMdlFromQr`.
- **NFC tap**: call `verifyMdlFromNfc` and ask the holder to hold their phone
  against the back of yours. The plugin turns on NFC reader mode for your
  activity while it waits and supports ISO 18013-5 NFC **static handover** and
  **negotiated handover** (used by Apple Wallet and Google Wallet).

Either way the data then moves over Bluetooth LE (or NFC, if that's all a
static-handover wallet offers).

```dart
final verifier = WalletVerifierApi();

if (await verifier.isAndroidReaderSupported() &&
    await verifier.requestAndroidReaderPermissions()) {
  // qr is the scanned string, e.g. from mobile_scanner.
  if (MdocQrEngagement.isEngagement(qr)) {
    final result = await verifier.verifyMdlFromQr(qr); // MdlElement.doorCheck
    if (result.isVerified && result.ageOver21 == true) {
      // Compare result.portrait with the person in front of you.
    }
  }
}

// NFC: show a "hold the phone to the back of this device" screen, then:
switch (await verifier.getNfcStatus()) {
  case MdlNfcStatus.enabled:
    final result = await verifier.verifyMdlFromNfc(); // waits up to 60 s
    // result.engagement: MdlEngagement.nfcNegotiatedHandover, ...
  case MdlNfcStatus.disabled:
    await verifier.openNfcSettings();
  case MdlNfcStatus.unsupported:
    // Fall back to QR.
}
```

`cancelMdlRead()` stops either kind of read (and turns NFC reader mode off).
Keep your waiting screen in the foreground: Android turns reader mode off when
the activity pauses.

`MdlReadResult.isVerified` is `dataIntegrityVerified && issuerTrusted`:

- `dataIntegrityVerified`: the issuer's signature on the Mobile Security
  Object, the digest of every returned element, the validity window and the
  holder device's authentication for this session all check out.
- `issuerTrusted`: the document signer chains to a trusted issuer root. The
  plugin bundles Arizona's four IACA roots (see
  [android/TRUST_ANCHORS.md](android/TRUST_ANCHORS.md)). Add more with
  `additionalTrustedRootsPem`, or pass a signed AAMVA VICAL as `vical:` (its
  signature and AAMVA chain are checked first) to trust every participating state.

Every element is requested with intent to retain = false. The plugin doesn't log
or store the data; keep it that way in your app.

Requirements: Android 12+ with Bluetooth LE at runtime, `minSdk` 26. The plugin
declares `BLUETOOTH_SCAN` (with `neverForLocation`), `BLUETOOTH_CONNECT`,
`BLUETOOTH_ADVERTISE` and `NFC` (NFC hardware is optional). Your scanner needs `CAMERA`. If you minify, the plugin
ships consumer R8 rules that keep Multipaz.

## Migrating from 0.0.x

`verifyAge` and `MobileDriversLicenseElement` still work but are deprecated:

```dart
// Before
await verifier.verifyAge(
  [MobileDriversLicenseElement.ageAtLeast],
  age: 21,
);

// After: you also get the outcome back
final outcome = await verifier.displayDriversLicense(
  [const DisplayElement.ageAtLeast(21)],
);
```

Unlike the old version, `verifyAge` now completes only after the request
finishes, and it throws `WalletVerifierException` on failure instead of
ignoring the error.

## Testing

The Simulator and devices with the "Mobile Document Reader (Developer)" profile
from [Profiles and Logs](https://developer.apple.com/bug-reporting/profiles-and-logs/?name=mobile%20document%20reader)
simulate a successful read and show a mock response. This works even if you
don't live in an area that supports mobile IDs.

See the [example app](example/lib/main.dart) for a complete sample.
