package com.kiwis08.wallet_verifier_api

import android.Manifest
import android.app.Activity
import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import org.multipaz.context.initializeApplication

/**
 * Android side of wallet_verifier_api.
 *
 * The iOS display-request API (Apple's Verifier API) has no Android equivalent, so Android
 * implements a separate ISO/IEC 18013-5 reader on top of Multipaz:
 *  - isAndroidReaderSupported
 *  - requestAndroidReaderPermissions
 *  - readMdlFromQr
 *  - cancelMdlRead
 * The iOS method names return `false` / `notSupported` here.
 */
class WalletVerifierApiPlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware,
    PluginRegistry.RequestPermissionsResultListener {

    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private lateinit var reader: MdlProximityReader
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var activeRead: Job? = null

    private var activityBinding: ActivityPluginBinding? = null
    private var pendingPermissionResult: Result? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        // Multipaz's BLE transports look up the application context through this.
        initializeApplication(context)
        reader = MdlProximityReader(MdlTrustStore(context))
        channel = MethodChannel(binding.binaryMessenger, "wallet_verifier_api")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        scope.cancel()
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            // iOS Verifier API: not available on Android.
            "isSupported", "isNationalIDCardRegionSupported" -> result.success(false)
            "prepare", "readerInstanceIdentifier", "requestDisplay" ->
                result.error("notSupported", "Apple's Verifier API is only available on iOS", null)

            "isAndroidReaderSupported" -> result.success(isReaderSupported())
            "hasAndroidReaderPermissions" -> result.success(missingPermissions().isEmpty())
            "requestAndroidReaderPermissions" -> requestPermissions(result)
            "readMdlFromQr" -> readMdlFromQr(call, result)
            "cancelMdlRead" -> {
                activeRead?.cancel(CancellationException("Cancelled from Dart"))
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun isReaderSupported(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return false
        if (!context.packageManager.hasSystemFeature(PackageManager.FEATURE_BLUETOOTH_LE)) return false
        return context.getSystemService(BluetoothManager::class.java)?.adapter != null
    }

    private fun requiredPermissions(): List<String> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            listOf(
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.BLUETOOTH_CONNECT,
                Manifest.permission.BLUETOOTH_ADVERTISE,
            )
        } else {
            emptyList()
        }

    private fun missingPermissions(): List<String> = requiredPermissions().filter {
        ContextCompat.checkSelfPermission(context, it) != PackageManager.PERMISSION_GRANTED
    }

    private fun requestPermissions(result: Result) {
        val missing = missingPermissions()
        if (missing.isEmpty()) {
            result.success(true)
            return
        }
        val activity: Activity = activityBinding?.activity ?: run {
            result.error("notAllowed", "No foreground activity to request Bluetooth permissions", null)
            return
        }
        if (pendingPermissionResult != null) {
            result.error("systemBusy", "A permission request is already in progress", null)
            return
        }
        pendingPermissionResult = result
        activity.requestPermissions(missing.toTypedArray(), PERMISSION_REQUEST_CODE)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != PERMISSION_REQUEST_CODE) return false
        pendingPermissionResult?.success(missingPermissions().isEmpty())
        pendingPermissionResult = null
        return true
    }

    private fun readMdlFromQr(call: MethodCall, result: Result) {
        if (!isReaderSupported()) {
            result.error("notSupported", "This device can't act as an mDL reader (needs Android 12+ and Bluetooth LE)", null)
            return
        }
        if (missingPermissions().isNotEmpty()) {
            result.error("notAllowed", "Bluetooth permissions not granted; call requestAndroidReaderPermissions()", null)
            return
        }
        val qrContent = call.argument<String>("qrContent")
        val elements = call.argument<List<String>>("elements")
        if (qrContent == null || elements.isNullOrEmpty()) {
            result.error("invalidArgument", "qrContent and a non-empty elements list are required", null)
            return
        }
        val request = MdlReadRequest(
            docType = call.argument<String>("docType") ?: MDL_DOCTYPE,
            namespace = call.argument<String>("namespace") ?: MDL_NAMESPACE,
            elements = elements,
            timeoutMillis = (call.argument<Number>("timeoutMillis") ?: 45_000).toLong(),
            additionalRootsPem = call.argument<List<String>>("additionalTrustedRootsPem") ?: emptyList(),
            vical = call.argument<ByteArray>("vical"),
        )
        activeRead?.cancel(CancellationException("Superseded by a new read"))
        activeRead = scope.launch {
            try {
                result.success(reader.readFromQr(qrContent, request))
            } catch (e: MdlReadException) {
                result.error(e.code, e.message, null)
            } catch (e: CancellationException) {
                result.error("cancelled", "The read was cancelled", null)
            } catch (e: Throwable) {
                result.error("unknown", e.message ?: e.toString(), null)
            }
        }
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivity() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
    }

    companion object {
        const val MDL_DOCTYPE = "org.iso.18013.5.1.mDL"
        const val MDL_NAMESPACE = "org.iso.18013.5.1"
        private const val PERMISSION_REQUEST_CODE = 0x6D646C // "mdl"
    }
}
