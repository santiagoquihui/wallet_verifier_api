package com.kiwis08.wallet_verifier_api

import kotlinx.coroutines.test.runTest
import java.io.File
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue

internal class MdlTrustStoreTest {
    // Unit tests run with the module directory as the working directory.
    private val assetsRoot = File("src/main/assets")

    private fun fileLoader(dir: String): List<Pair<String, String>> =
        File(assetsRoot, dir).listFiles { f -> f.name.endsWith(".pem") }
            ?.sortedBy { it.name }
            ?.map { it.name to it.readText() }
            ?: emptyList()

    private val vical: ByteArray =
        javaClass.classLoader!!.getResourceAsStream("aamva_vical_2026-11-09.cbor")!!.readBytes()

    @Test
    fun bundledArizonaRootsLoad() = runTest {
        val store = MdlTrustStore(::fileLoader)
        val names = store.bundledRootNames()
        assertEquals(4, names.size, "$names")
        for (cn in listOf("AvocetIACA", "AzWalletIACA", "GoogleIACA", "SamsungIACA")) {
            assertTrue(names.any { it == "Arizona Department of Transportation ($cn)" }, "$cn missing from $names")
        }
        assertEquals(4, store.trustManager(emptyList(), null).getTrustPoints().size)
    }

    @Test
    fun signedAamvaVicalIsAccepted() = runTest {
        val store = MdlTrustStore(::fileLoader)
        val points = store.trustManager(emptyList(), vical).getTrustPoints()
        // 4 bundled + every issuer in the VICAL (24 on 2026-11-09).
        assertTrue(points.size >= 4 + 20, "only ${points.size} trust points")
    }

    @Test
    fun tamperedVicalIsRejected() = runTest {
        val store = MdlTrustStore(::fileLoader)
        val tampered = vical.copyOf().also { it[it.size / 2] = (it[it.size / 2].toInt() xor 0x01).toByte() }
        assertFailsWith<Throwable> { store.trustManager(emptyList(), tampered) }
    }

    @Test
    fun vicalFromUnknownProviderIsRejected() = runTest {
        // No bundled VICAL signer roots -> even a correctly signed VICAL is refused.
        val store = MdlTrustStore { dir -> if (dir == MdlTrustStore.VICAL_SIGNER_DIR) emptyList() else fileLoader(dir) }
        val e = assertFailsWith<IllegalArgumentException> { store.trustManager(emptyList(), vical) }
        assertTrue(e.message!!.contains("trusted VICAL provider"))
    }
}
