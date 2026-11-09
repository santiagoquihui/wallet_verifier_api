package com.kiwis08.wallet_verifier_api

import android.app.Activity
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.tech.IsoDep
import android.util.Log
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import org.multipaz.nfc.NfcIsoTag
import org.multipaz.nfc.NfcIsoTagAndroid
import org.multipaz.nfc.NfcScanOptions
import org.multipaz.nfc.NfcTagLostException
import org.multipaz.nfc.NfcTagReader
import java.io.IOException
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.coroutines.CoroutineContext
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * [NfcTagReader] backed by [NfcAdapter.enableReaderMode] on the Flutter activity.
 *
 * Multipaz's own Android reader drives a Compose bottom sheet (AndroidPromptModel), which a Flutter
 * app doesn't have; the waiting UI lives in Dart instead, so this reader shows no dialog.
 * Reader mode stays on only while [scan] is suspended and is turned off on success, error or
 * cancellation. Android also turns it off when the activity is paused.
 */
internal class ActivityNfcTagReader(
    private val activityProvider: () -> Activity?,
) : NfcTagReader {
    override val external: Boolean get() = false
    override val dialogAlwaysShown: Boolean get() = false
    override val dialogNeverShown: Boolean get() = true

    override suspend fun <T : Any> scan(
        message: String?,
        tagInteractionFunc: suspend (tag: NfcIsoTag) -> T?,
        options: NfcScanOptions,
        context: CoroutineContext,
    ): T {
        val activity = activityProvider()
            ?: throw MdlReadException("notSupported", "No foreground activity to enable NFC reader mode")
        val adapter = NfcAdapter.getDefaultAdapter(activity)
            ?: throw MdlReadException("notSupported", "This device has no NFC")
        if (!adapter.isEnabled) {
            throw MdlReadException("nfcDisabled", "NFC is turned off")
        }
        return withContext(Dispatchers.Main) {
            try {
                suspendCancellableCoroutine { continuation ->
                    val done = AtomicBoolean(false)
                    val callback = NfcAdapter.ReaderCallback { tag: Tag? ->
                        if (tag == null || done.get()) return@ReaderCallback
                        val isoDep = IsoDep.get(tag) ?: run {
                            Log.i(TAG, "Ignoring non-ISO-DEP tag")
                            return@ReaderCallback
                        }
                        try {
                            isoDep.connect()
                            isoDep.timeout = TAG_TIMEOUT_MILLIS
                            // onTagDiscovered runs on a binder thread and must not return until the
                            // tag interaction is over, hence runBlocking.
                            val result = runBlocking {
                                tagInteractionFunc(NfcIsoTagAndroid(isoDep, context) { })
                            }
                            if (result != null && done.compareAndSet(false, true)) {
                                continuation.resume(result)
                            }
                            // null: not an mdoc (or locked phone); keep listening.
                        } catch (e: NfcTagLostException) {
                            Log.i(TAG, "Tag lost, keep listening")
                        } catch (e: IOException) {
                            Log.i(TAG, "Tag I/O error, keep listening: ${e.message}")
                        } catch (e: CancellationException) {
                            // Scan cancelled while talking to the tag.
                        } catch (e: Exception) {
                            if (done.compareAndSet(false, true)) continuation.resumeWithException(e)
                        }
                    }
                    adapter.enableReaderMode(
                        activity,
                        callback,
                        NfcAdapter.FLAG_READER_NFC_A or NfcAdapter.FLAG_READER_NFC_B or
                            NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK,
                        null,
                    )
                    Log.i(TAG, "NFC reader mode enabled")
                }
            } finally {
                runCatching { adapter.disableReaderMode(activity) }
                Log.i(TAG, "NFC reader mode disabled")
            }
        }
    }

    companion object {
        private const val TAG = "WalletVerifierNfc"
        private const val TAG_TIMEOUT_MILLIS = 20_000
    }
}
