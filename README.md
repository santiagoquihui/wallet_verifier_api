# wallet_verifier_api

A Flutter wrapper around Apple's [Verifier API](https://developer.apple.com/wallet/id-verifier/)
(the ProximityReader framework). It lets an iPhone check IDs held in Apple Wallet
in person, using tap-to-present.

The plugin supports **display requests**. The system shows the requested
information (name, age, "age 21+", and so on) to the person checking the ID in
a secure sheet. Your app never receives the values. It only gets the
verifier's decision: approved, rejected, or dismissed.

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
