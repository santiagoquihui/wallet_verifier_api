package com.kiwis08.wallet_verifier_api

import org.multipaz.cbor.Bstr
import org.multipaz.cbor.Nint
import org.multipaz.cbor.Simple
import org.multipaz.cbor.Tagged
import org.multipaz.cbor.Tstr
import org.multipaz.cbor.Uint
import org.multipaz.cbor.addCborMap
import org.multipaz.cbor.buildCborArray
import org.multipaz.cbor.buildCborMap
import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals

internal class CborToFlutterTest {
    @Test
    fun convertsMdlElementShapes() {
        assertEquals("ADA", cborToFlutter(Tstr("ADA")))
        assertEquals(true, cborToFlutter(Simple.TRUE))
        assertEquals(false, cborToFlutter(Simple.FALSE))
        assertEquals(null, cborToFlutter(Simple.NULL))
        assertEquals(42L, cborToFlutter(Uint(42UL)))
        assertEquals(-5L, cborToFlutter(Nint(5UL)))
        // full-date (tag 1004) as used by birth_date / expiry_date
        assertEquals("1990-01-31", cborToFlutter(Tagged(1004, Tstr("1990-01-31"))))
        assertContentEquals(byteArrayOf(1, 2, 3), cborToFlutter(Bstr(byteArrayOf(1, 2, 3))) as ByteArray)
        assertEquals(
            listOf(mapOf("vehicle_category_code" to "D")),
            cborToFlutter(buildCborArray { addCborMap { put("vehicle_category_code", "D") } }),
        )
        assertEquals(mapOf("1" to "x"), cborToFlutter(buildCborMap { put(1L, "x") }))
    }
}
