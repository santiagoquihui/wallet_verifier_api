package com.kiwis08.wallet_verifier_api

import org.multipaz.mdoc.connectionmethod.MdocConnectionMethodBle
import org.multipaz.mdoc.connectionmethod.MdocConnectionMethodNfc
import org.multipaz.util.UUID
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class SelectConnectionMethodTest {
    private val uuid = UUID.randomUUID()
    private val central = MdocConnectionMethodBle(false, true, null, uuid)
    private val peripheral = MdocConnectionMethodBle(true, false, uuid, null)
    private val nfc = MdocConnectionMethodNfc(255, 256)

    @Test
    fun prefersPeripheralServerThenCentralClient() {
        assertEquals(peripheral, selectConnectionMethod(listOf(nfc, central, peripheral), allowNfc = true))
        assertEquals(central, selectConnectionMethod(listOf(nfc, central), allowNfc = true))
    }

    @Test
    fun nfcOnlyWhenAllowed() {
        assertEquals(nfc, selectConnectionMethod(listOf(nfc), allowNfc = true))
        assertNull(selectConnectionMethod(listOf(nfc), allowNfc = false))
        assertNull(selectConnectionMethod(emptyList(), allowNfc = true))
    }

    @Test
    fun transportNames() {
        assertEquals("Bluetooth", transportName(central))
        assertEquals("NFC", transportName(nfc))
    }
}
