package com.kiwis08.wallet_verifier_api

import android.content.Context
import kotlinx.io.bytestring.ByteString
import org.multipaz.crypto.X509Cert
import org.multipaz.mdoc.vical.SignedVical
import org.multipaz.trustmanagement.ConfigurableTrustManager
import org.multipaz.trustmanagement.TrustEntry
import org.multipaz.trustmanagement.TrustEntryVical
import org.multipaz.trustmanagement.TrustEntryX509Cert
import org.multipaz.trustmanagement.TrustManagerInterface
import org.multipaz.trustmanagement.TrustMetadata

/**
 * Trust anchors for issuer (IACA) certificates.
 *
 * Stage 1 seeds the trust manager with the Arizona IACA roots bundled under
 * `assets/wallet_verifier_api/iaca/`. Callers can add more PEM roots per request.
 *
 * Stage 3 hook: pass the bytes of an AAMVA VICAL (downloaded and refreshed by the app or a
 * backend). The VICAL signature is checked by [SignedVical.parse] and its signer chain must
 * validate up to the bundled AAMVA DTS root in `assets/wallet_verifier_api/vical_signers/`.
 */
internal class MdlTrustStore(
    /** Lists `(fileName, pemText)` for the `.pem` files in an asset directory. */
    private val loadPemAssets: (dir: String) -> List<Pair<String, String>>,
) {
    constructor(context: Context) : this({ dir -> loadPemAssetsFrom(context, dir) })


    private val bundledIacaEntries: List<TrustEntry> by lazy { loadBundledIacaRoots() }

    private val bundledVicalSignerRoots: List<X509Cert> by lazy {
        loadPemAssets(VICAL_SIGNER_DIR).map { (_, pem) -> X509Cert.fromPem(pem) }
    }

    /** Names of the bundled IACA roots, for diagnostics. */
    fun bundledRootNames(): List<String> =
        bundledIacaEntries.mapNotNull { it.metadata.displayName }

    suspend fun trustManager(
        additionalRootsPem: List<String>,
        vical: ByteArray?,
    ): TrustManagerInterface {
        val entries = mutableListOf<TrustEntry>()
        entries += bundledIacaEntries
        additionalRootsPem.forEachIndexed { index, pem ->
            val cert = X509Cert.fromPem(pem)
            entries += TrustEntryX509Cert(
                identifier = "extra_$index",
                metadata = TrustMetadata(displayName = cert.subject.name),
                certificate = cert,
            )
        }
        if (vical != null) {
            entries += verifiedVicalEntry(vical)
        }
        return ConfigurableTrustManager(identifier = "wallet_verifier_api", entries = entries)
    }

    private suspend fun verifiedVicalEntry(vical: ByteArray): TrustEntryVical {
        // Checks the COSE_Sign1 signature against the leaf of the embedded x5chain.
        val signedVical = SignedVical.parse(vical)
        val chain = signedVical.vicalProviderCertificateChain
        chain.validate()
        val root = chain.certificates.last()
        require(bundledVicalSignerRoots.any { it.encoded == root.encoded }) {
            "VICAL is not signed by a trusted VICAL provider"
        }
        return TrustEntryVical(
            identifier = "vical",
            metadata = TrustMetadata(displayName = signedVical.vical.vicalProvider),
            encodedSignedVical = ByteString(vical),
        )
    }

    private fun loadBundledIacaRoots(): List<TrustEntry> =
        loadPemAssets(IACA_DIR).map { (name, pem) ->
            val cert = X509Cert.fromPem(pem)
            TrustEntryX509Cert(
                identifier = name,
                metadata = TrustMetadata(displayName = displayNameFor(cert)),
                certificate = cert,
            )
        }

    private fun displayNameFor(cert: X509Cert): String {
        // e.g. "Arizona Department of Transportation (GoogleIACA)"
        val parts = cert.subject.components
        val org = parts["2.5.4.10"]?.value
        val cn = parts["2.5.4.3"]?.value
        return when {
            org != null && cn != null -> "$org ($cn)"
            else -> cert.subject.name
        }
    }

    companion object {
        private fun loadPemAssetsFrom(context: Context, dir: String): List<Pair<String, String>> {
            val names = context.assets.list(dir)?.filter { it.endsWith(".pem") }?.sorted() ?: emptyList()
            return names.map { name ->
                name to context.assets.open("$dir/$name").bufferedReader().use { it.readText() }
            }
        }

        const val IACA_DIR = "wallet_verifier_api/iaca"
        const val VICAL_SIGNER_DIR = "wallet_verifier_api/vical_signers"
    }
}
