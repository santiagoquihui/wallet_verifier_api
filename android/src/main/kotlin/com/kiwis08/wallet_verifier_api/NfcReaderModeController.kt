package com.kiwis08.wallet_verifier_api

import android.app.Activity
import android.app.Application
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.os.Bundle
import android.util.Log

/**
 * Owns NFC reader mode for the Flutter activity.
 *
 * Reader mode is on while either a read is in progress ([beginRead]) or the app asked to hold NFC
 * ([startHold]), e.g. for as long as its verify screen is open. One [NfcAdapter.ReaderCallback]
 * stays registered and routes each tag to the current read's handler; with no read in progress the
 * tag is swallowed. That keeps Android's "New tag scanned" sheet from popping up when a wallet
 * touches the phone between reads, or is still touching it right after a read.
 *
 * Reader mode only applies while the activity is resumed: it is turned off when the activity
 * pauses and turned back on when it resumes, if still wanted. Main thread only, except the
 * callback, which runs on a binder thread.
 */
internal class NfcReaderModeController {
    private var activity: Activity? = null
    private var holdRequested = false
    private var resumed = true
    private var enabledOn: Activity? = null

    @Volatile
    private var readHandler: ((Tag) -> Unit)? = null

    private val dispatcher = NfcAdapter.ReaderCallback { tag: Tag? ->
        if (tag == null) return@ReaderCallback
        val handler = readHandler
        if (handler == null) {
            // No read in progress: swallow the tag so the system doesn't show its tag sheet.
            Log.i(TAG, "Tag ignored (holding NFC, no read in progress)")
        } else {
            handler(tag)
        }
    }

    private val lifecycleCallbacks = object : Application.ActivityLifecycleCallbacks {
        override fun onActivityResumed(a: Activity) {
            if (a !== activity) return
            resumed = true
            apply()
        }

        override fun onActivityPaused(a: Activity) {
            if (a !== activity) return
            resumed = false
            apply()
        }

        override fun onActivityCreated(a: Activity, savedInstanceState: Bundle?) {}
        override fun onActivityStarted(a: Activity) {}
        override fun onActivityStopped(a: Activity) {}
        override fun onActivitySaveInstanceState(a: Activity, outState: Bundle) {}
        override fun onActivityDestroyed(a: Activity) {}
    }

    /** Whether reader mode is wanted right now (independent of the activity being resumed). */
    val isWanted: Boolean get() = holdRequested || readHandler != null

    val isHolding: Boolean get() = holdRequested

    fun attach(newActivity: Activity) {
        if (activity === newActivity) return
        detach()
        activity = newActivity
        // A freshly attached activity is normally being created or resumed; pause will correct it.
        resumed = true
        newActivity.application.registerActivityLifecycleCallbacks(lifecycleCallbacks)
        apply()
    }

    fun detach() {
        val current = activity ?: return
        disable()
        current.application.unregisterActivityLifecycleCallbacks(lifecycleCallbacks)
        activity = null
    }

    /** Keeps reader mode on until [stopHold], swallowing tags while no read runs. */
    fun startHold(): Boolean {
        holdRequested = true
        apply()
        return enabledOn != null
    }

    fun stopHold() {
        holdRequested = false
        apply()
    }

    /** Routes tags to [handler] until [endRead]; turns reader mode on if needed. */
    fun beginRead(handler: (Tag) -> Unit) {
        readHandler = handler
        apply(force = true)
    }

    /** Stops routing tags to [handler]. Reader mode stays on (swallowing tags) if held. */
    fun endRead(handler: (Tag) -> Unit) {
        if (readHandler === handler) readHandler = null
        apply()
    }

    fun release() {
        holdRequested = false
        readHandler = null
        detach()
    }

    private fun apply(force: Boolean = false) {
        val current = activity
        if (current == null || !resumed || !isWanted) {
            disable()
            return
        }
        if (enabledOn === current && !force) return
        val adapter = NfcAdapter.getDefaultAdapter(current) ?: return
        val ok = runCatching {
            adapter.enableReaderMode(current, dispatcher, READER_FLAGS, null)
        }.onFailure { Log.w(TAG, "Could not enable NFC reader mode: ${it.message}") }.isSuccess
        if (ok) {
            if (enabledOn == null) Log.i(TAG, "NFC reader mode enabled")
            enabledOn = current
        }
    }

    private fun disable() {
        val on = enabledOn ?: return
        enabledOn = null
        NfcAdapter.getDefaultAdapter(on)?.let { adapter ->
            runCatching { adapter.disableReaderMode(on) }
        }
        Log.i(TAG, "NFC reader mode disabled")
    }

    companion object {
        private const val TAG = "WalletVerifierNfc"
        const val READER_FLAGS = NfcAdapter.FLAG_READER_NFC_A or NfcAdapter.FLAG_READER_NFC_B or
            NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK
    }
}
