# Bundled trust anchors (Android mDL reader)

These are public certificates. They are bundled under
`src/main/assets/wallet_verifier_api/` and loaded by `MdlTrustStore`.

Extracted on 2026-11-09 from the AAMVA Digital Trust Service VICAL
`vc-2026-11-09-1794186438256` (https://vical.dts.aamva.org/currentVical,
download: https://vical.dts.aamva.org/vical/vc/vc-2026-11-09-1794186438256).
The VICAL's COSE signature was checked and its signer chain
(AAMVA Prod Vical-Signer-02 -> AAMVA DTS Issuing CA -> AAMVA DTS Root CA)
validated against https://vical.dts.aamva.org/certificates/ca before extraction.
Google's issuer list
(https://developers.google.com/wallet/identity/verify/supported-issuers-iaca-certs)
links Arizona to the AAMVA VICAL. The SHA-256 fingerprints match
https://mdl.peculiarventures.com/ (Arizona, source AAMVA).

## Arizona IACA roots (`iaca/`)

All four: issuer = subject (self-signed), ECDSA P-256, valid 2025-12-15 to 2035-12-15,
docType `org.iso.18013.5.1.mDL`.
Subject: `L=Phoenix, ST=US-AZ, C=US, OU=IT, O=Arizona Department of Transportation, CN=<CN>`

| File | CN | SHA-256 (DER) | Likely wallet |
| --- | --- | --- | --- |
| `az_google_iaca.pem` | GoogleIACA | `cba92976e03a40064f0f6f37f4b2a9ef039487951dd1125f59a099be305ee463` | Google Wallet |
| `az_samsung_iaca.pem` | SamsungIACA | `ce5e1844eb2f1453232a04ab5850ce264ae27ad940b4d13f47ccd7446a516ffd` | Samsung Wallet |
| `az_azwallet_iaca.pem` | AzWalletIACA | `116d21b707180295329d9c3835f7fdaa3d58a945a2635987abed985e28524ab4` | Arizona Mobile ID app |
| `az_avocet_iaca.pem` | AvocetIACA | `1f3a4a6fe42ca4b2f64b4957971607b3ecd62406e0631721168f02aafd9f6b8a` | Unconfirmed (probably Apple Wallet) |

The mapping of AvocetIACA to Apple Wallet is a guess; nothing official says so.

No Apple-specific root is needed to trust an ID read from Apple Wallet: the
document signer chains to the issuing state's IACA (one of the roots above for
Arizona), not to Apple. Apple's root CA only matters for *reader*
authentication (the reader proving its identity to the wallet), which this
plugin doesn't do yet. If an Apple Wallet read comes back with
`issuerTrusted == false`, `documentSignerIssuer` names the IACA that signed it.
Older Arizona roots (three `CN=MVMProdCA` certificates valid 2024-08-16 to 2034-08-16)
appeared in earlier VICALs (e.g. 2025-11-08) but are no longer in the current one,
so they are not bundled.

## VICAL signer root (`vical_signers/`)

| File | Subject | SHA-256 (DER) | Source |
| --- | --- | --- | --- |
| `aamva_dts_root_ca.pem` | `CN=AAMVA DTS Root CA, OU=Certification Authorities, O=American Association of Motor Vehicle Administrators, C=US` | `3b545614be42ef018b1c1050ebce9b96fa33ecec0c7115b8e70664c6454c5104` | https://vical.dts.aamva.org/certificates/ca |

Only used to accept a VICAL passed to `verifyMdlFromQr(vical: ...)`; it is not an
issuer trust anchor.

## Refreshing

States add and rotate IACA roots. Re-extract from the current VICAL, or (preferred)
download the VICAL in the app or a backend, refresh it daily (`nextUpdate` is ~24h),
and pass the bytes as `vical:`. Use of the VICAL is subject to AAMVA's DTS terms for
relying parties.
