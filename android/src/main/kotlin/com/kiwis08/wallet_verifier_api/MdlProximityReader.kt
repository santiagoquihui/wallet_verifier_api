package com.kiwis08.wallet_verifier_api

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.withTimeout
import org.multipaz.cbor.Bstr
import org.multipaz.cbor.Cbor
import org.multipaz.cbor.CborArray
import org.multipaz.cbor.CborDouble
import org.multipaz.cbor.CborFloat
import org.multipaz.cbor.CborMap
import org.multipaz.cbor.DataItem
import org.multipaz.cbor.Nint
import org.multipaz.cbor.Simple
import org.multipaz.cbor.Tagged
import org.multipaz.cbor.Tstr
import org.multipaz.cbor.Uint
import org.multipaz.cbor.buildCborArray
import org.multipaz.crypto.AsymmetricKey
import org.multipaz.crypto.Crypto
import org.multipaz.mdoc.connectionmethod.MdocConnectionMethod
import org.multipaz.mdoc.connectionmethod.MdocConnectionMethodBle
import org.multipaz.mdoc.engagement.DeviceEngagement
import org.multipaz.mdoc.request.buildDeviceRequest
import org.multipaz.mdoc.response.DeviceResponse
import org.multipaz.mdoc.role.MdocRole
import org.multipaz.mdoc.sessionencryption.SessionEncryption
import org.multipaz.mdoc.transport.MdocTransportFactory
import org.multipaz.mdoc.transport.MdocTransportOptions
import org.multipaz.util.Constants
import org.multipaz.util.fromBase64Url

/** A failure that maps onto a `WalletVerifierErrorCode` name on the Dart side. */
internal class MdlReadException(
    val code: String,
    message: String,
    cause: Throwable? = null,
) : Exception(message, cause)

internal data class MdlReadRequest(
    val docType: String,
    val namespace: String,
    val elements: List<String>,
    val timeoutMillis: Long,
    val additionalRootsPem: List<String>,
    val vical: ByteArray?,
)

/**
 * ISO/IEC 18013-5 mdoc reader: QR device engagement -> BLE -> DeviceRequest -> DeviceResponse.
 *
 * Personal data is only held in memory and returned to Dart; nothing is logged or stored.
 */
internal class MdlProximityReader(private val trustStore: MdlTrustStore) {

    suspend fun readFromQr(qrContent: String, request: MdlReadRequest): Map<String, Any?> {
        val trimmed = qrContent.trim()
        if (!trimmed.startsWith(MDOC_URI_PREFIX)) {
            throw MdlReadException("invalidArgument", "Not an ISO 18013-5 engagement QR code (expected an mdoc: URI)")
        }
        val encodedDeviceEngagement = try {
            trimmed.substring(MDOC_URI_PREFIX.length).fromBase64Url()
        } catch (e: Exception) {
            throw MdlReadException("invalidArgument", "mdoc: URI is not valid base64url", e)
        }
        val deviceEngagement = try {
            DeviceEngagement.fromDataItem(Cbor.decode(encodedDeviceEngagement))
        } catch (e: Exception) {
            throw MdlReadException("invalidArgument", "Could not parse the device engagement: ${e.message}", e)
        }
        return try {
            withTimeout(request.timeoutMillis) {
                // QR engagement uses a null Handover (ISO 18013-5 9.1.5.1).
                readOverBle(encodedDeviceEngagement, deviceEngagement, Simple.NULL, request)
            }
        } catch (e: TimeoutCancellationException) {
            throw MdlReadException("timedOut", "Timed out waiting for the wallet", e)
        }
    }

    // TODO(stage 2): NFC engagement. Use org.multipaz.nfc.NfcTagReader + mdocReaderNfcHandover()
    //  to obtain the DeviceEngagement and Handover, then call readOverBle() (or keep NFC as the
    //  transport) with that handover instead of Simple.NULL.

    private suspend fun readOverBle(
        encodedDeviceEngagement: ByteArray,
        deviceEngagement: DeviceEngagement,
        handover: DataItem,
        request: MdlReadRequest,
    ): Map<String, Any?> {
        val connectionMethod = MdocConnectionMethod
            .disambiguate(deviceEngagement.connectionMethods, MdocRole.MDOC_READER)
            .filterIsInstance<MdocConnectionMethodBle>()
            // Prefer mdoc peripheral server mode (wallet advertises, we connect), the most widely supported.
            .sortedByDescending { it.supportsPeripheralServerMode }
            .firstOrNull()
            ?: throw MdlReadException("notSupported", "The wallet did not offer a Bluetooth LE connection")

        val eReaderKey = Crypto.createEcPrivateKey(deviceEngagement.eDeviceKey.curve)
        val encodedEReaderKey = Cbor.encode(eReaderKey.publicKey.toCoseKey().toDataItem())
        val sessionTranscript = buildCborArray {
            add(Tagged(Tagged.ENCODED_CBOR, Bstr(encodedDeviceEngagement)))
            add(Tagged(Tagged.ENCODED_CBOR, Bstr(encodedEReaderKey)))
            add(handover)
        }
        val encodedSessionTranscript = Cbor.encode(sessionTranscript)

        val deviceRequest = buildDeviceRequest(sessionTranscript = sessionTranscript) {
            addDocRequest(
                docType = request.docType,
                // intentToRetain = false for every element.
                nameSpaces = mapOf(request.namespace to request.elements.associateWith { false }),
                docRequestInfo = null,
            )
        }

        val sessionEncryption = SessionEncryption(
            MdocRole.MDOC_READER,
            eReaderKey,
            deviceEngagement.eDeviceKey,
            encodedSessionTranscript,
        )
        val transport = MdocTransportFactory.Default.createTransport(
            connectionMethod,
            MdocRole.MDOC_READER,
            MdocTransportOptions(),
        )
        val encodedDeviceResponse: ByteArray
        try {
            try {
                transport.open(deviceEngagement.eDeviceKey)
                transport.sendMessage(
                    sessionEncryption.encryptMessage(Cbor.encode(deviceRequest.toDataItem()), null)
                )
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                throw MdlReadException("transportFailed", "Could not connect to the wallet over Bluetooth: ${e.message}", e)
            }
            val sessionData = try {
                transport.waitForMessage()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                throw MdlReadException("transportFailed", "Bluetooth connection lost: ${e.message}", e)
            }
            if (sessionData.isEmpty()) {
                throw MdlReadException("cancelled", "The wallet ended the session without sharing")
            }
            val (message, status) = sessionEncryption.decryptMessage(sessionData)
            if (status != Constants.SESSION_DATA_STATUS_SESSION_TERMINATION) {
                runCatching {
                    transport.sendMessage(
                        SessionEncryption.encodeStatus(Constants.SESSION_DATA_STATUS_SESSION_TERMINATION)
                    )
                }
            }
            encodedDeviceResponse = message
                ?: throw MdlReadException("cancelled", "The wallet declined to share (status $status)")
        } finally {
            runCatching { transport.close() }
        }

        return evaluate(encodedDeviceResponse, sessionTranscript, AsymmetricKey.anonymous(eReaderKey), request)
    }

    private suspend fun evaluate(
        encodedDeviceResponse: ByteArray,
        sessionTranscript: DataItem,
        eReaderKey: AsymmetricKey,
        request: MdlReadRequest,
    ): Map<String, Any?> {
        val deviceResponse = try {
            DeviceResponse.fromDataItem(Cbor.decode(encodedDeviceResponse))
        } catch (e: Exception) {
            throw MdlReadException("invalidResponse", "Could not parse the DeviceResponse", e)
        }
        // verify() checks: MSO signature by the document signer, docType, MSO validity window,
        // digests of every returned element, and device authentication (MAC or signature) bound
        // to this session. It does NOT decide whether the issuer is trusted; see below.
        val integrityError = try {
            deviceResponse.verify(sessionTranscript = sessionTranscript, eReaderKey = eReaderKey)
            null
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            e.message ?: e.toString()
        }
        val document = deviceResponse.documents.firstOrNull { it.docType == request.docType }
            ?: throw MdlReadException(
                "invalidResponse",
                "No ${request.docType} returned (status ${deviceResponse.status}, errors ${deviceResponse.documentErrors})",
            )

        val elements = document.issuerNamespaces.data[request.namespace]
            ?.mapValues { (_, item) -> cborToFlutter(item.dataElementValue) }
            ?: emptyMap()
        val notReturned = document.errors[request.namespace]?.keys?.toList() ?: emptyList()

        val chain = document.issuerCertChain
        val documentSigner = chain.certificates.first()
        val trustResult = try {
            trustStore
                .trustManager(request.additionalRootsPem, request.vical)
                .verify(chain = chain.certificates, docType = request.docType)
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            return buildResult(
                request, elements, notReturned, integrityError, false, null,
                documentSigner.subject.name, documentSigner.issuer.name, document,
                trustError = "Trust store error: ${e.message}",
            )
        }
        return buildResult(
            request, elements, notReturned, integrityError,
            trustResult.isTrusted,
            trustResult.trustPoints.firstOrNull()?.metadata?.displayName,
            documentSigner.subject.name, documentSigner.issuer.name, document,
            trustError = if (trustResult.isTrusted) null else (trustResult.error?.message ?: "Issuer is not in the trust list"),
        )
    }

    private fun buildResult(
        request: MdlReadRequest,
        elements: Map<String, Any?>,
        notReturned: List<String>,
        integrityError: String?,
        issuerTrusted: Boolean,
        issuerName: String?,
        documentSignerSubject: String,
        documentSignerIssuer: String,
        document: org.multipaz.mdoc.response.MdocDocument,
        trustError: String?,
    ): Map<String, Any?> {
        val mso = runCatching { document.mso }.getOrNull()
        return mapOf(
            "docType" to request.docType,
            "namespace" to request.namespace,
            "elements" to elements,
            "notReturned" to notReturned,
            "dataIntegrityVerified" to (integrityError == null),
            "issuerTrusted" to issuerTrusted,
            "issuerName" to issuerName,
            "documentSignerSubject" to documentSignerSubject,
            "documentSignerIssuer" to documentSignerIssuer,
            "signedAt" to mso?.signedAt?.toString(),
            "validFrom" to mso?.validFrom?.toString(),
            "validUntil" to mso?.validUntil?.toString(),
            "integrityError" to integrityError,
            "trustError" to trustError,
        )
    }

    companion object {
        const val MDOC_URI_PREFIX = "mdoc:"
    }
}

/** Converts a CBOR value into something Flutter's StandardMessageCodec can carry. */
internal fun cborToFlutter(item: DataItem): Any? = when (item) {
    is Tstr -> item.value
    is Bstr -> item.value
    is Uint -> item.value.toLong()
    is Nint -> item.asNumber
    is Simple -> when (item.value) {
        Simple.TRUE.value -> true
        Simple.FALSE.value -> false
        else -> null
    }
    // tdate (0) and full-date (1004) carry strings; unwrap them and anything else tagged.
    is Tagged -> cborToFlutter(item.taggedItem)
    is CborArray -> item.items.map { cborToFlutter(it) }
    is CborMap -> item.items.entries.associate { (k, v) -> (cborToFlutter(k)?.toString() ?: "null") to cborToFlutter(v) }
    is CborFloat -> item.value.toDouble()
    is CborDouble -> item.value
    else -> item.toString()
}
