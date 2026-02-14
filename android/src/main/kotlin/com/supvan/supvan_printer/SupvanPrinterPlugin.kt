package com.supvan.supvan_printer

import android.Manifest
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry

import com.supvan.supvanlibrary.PrintingControlInfo.DrawObject
import com.supvan.supvanlibrary.PrintingControlInfo.PrintPage
import com.supvan.supvanlibrary.PrintingControlInfo.PrintParameter
import com.supvan.supvanlibrary.directprinttools.BluetoothManager
import com.supvan.supvanlibrary.directprinttools.Callback

import java.lang.reflect.Field
import java.lang.reflect.Method

/** SupvanPrinterPlugin */
class SupvanPrinterPlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware,
    PluginRegistry.RequestPermissionsResultListener {

    companion object {
        private const val TAG = "SupvanPrinter"
        private const val METHOD_CHANNEL = "com.supvan.printer/methods"
        private const val SCAN_EVENT_CHANNEL = "com.supvan.printer/scan"
        private const val CONNECTION_EVENT_CHANNEL = "com.supvan.printer/connection"
        private const val REQUEST_CODE_PERMISSIONS = 29571
    }

    private lateinit var methodChannel: MethodChannel
    private lateinit var scanEventChannel: EventChannel
    private lateinit var connectionEventChannel: EventChannel

    private var applicationContext: Context? = null
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null

    private var bluetoothManager: BluetoothManager? = null
    private var btAdapter: BluetoothAdapter? = null

    private var scanEventSink: EventChannel.EventSink? = null
    private var connectionEventSink: EventChannel.EventSink? = null

    private var isConnected = false
    private var discoveredDevices = mutableMapOf<String, BluetoothDevice>()

    private val mainHandler = Handler(Looper.getMainLooper())

    private var bluetoothReceiver: BroadcastReceiver? = null

    // Pending result to resume after permission grant
    private var pendingScanResult: Result? = null

    // ---- FlutterPlugin lifecycle ----

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext

        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL)
        methodChannel.setMethodCallHandler(this)

        scanEventChannel = EventChannel(binding.binaryMessenger, SCAN_EVENT_CHANNEL)
        scanEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                scanEventSink = events
            }
            override fun onCancel(arguments: Any?) {
                scanEventSink = null
            }
        })

        connectionEventChannel = EventChannel(binding.binaryMessenger, CONNECTION_EVENT_CHANNEL)
        connectionEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                connectionEventSink = events
            }
            override fun onCancel(arguments: Any?) {
                connectionEventSink = null
            }
        })
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        cleanup()
        applicationContext = null
    }

    // ---- ActivityAware lifecycle ----

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addRequestPermissionsResultListener(this)
        initBluetoothManager()
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activity = null
        activityBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addRequestPermissionsResultListener(this)
        initBluetoothManager()
    }

    override fun onDetachedFromActivity() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activity = null
        activityBinding = null
    }

    // ---- Permission handling ----

    /**
     * Returns the list of Bluetooth permissions that have NOT been granted yet.
     */
    private fun getMissingPermissions(): List<String> {
        val ctx = activity ?: applicationContext ?: return emptyList()
        val needed = mutableListOf<String>()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Android 12+
            if (ContextCompat.checkSelfPermission(ctx, Manifest.permission.BLUETOOTH_SCAN) != PackageManager.PERMISSION_GRANTED) {
                needed.add(Manifest.permission.BLUETOOTH_SCAN)
            }
            if (ContextCompat.checkSelfPermission(ctx, Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) {
                needed.add(Manifest.permission.BLUETOOTH_CONNECT)
            }
        }
        // Location is needed for classic BT discovery on all API levels
        if (ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            needed.add(Manifest.permission.ACCESS_FINE_LOCATION)
        }

        return needed
    }

    /**
     * Request missing permissions. Returns true if a request was launched (result is pending).
     */
    private fun requestPermissionsIfNeeded(result: Result): Boolean {
        val missing = getMissingPermissions()
        if (missing.isEmpty()) return false

        val act = activity
        if (act == null) {
            result.error("NO_ACTIVITY", "Cannot request permissions without an Activity", null)
            return true
        }

        pendingScanResult = result
        ActivityCompat.requestPermissions(act, missing.toTypedArray(), REQUEST_CODE_PERMISSIONS)
        return true // caller should wait
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray): Boolean {
        if (requestCode != REQUEST_CODE_PERMISSIONS) return false

        val pending = pendingScanResult
        pendingScanResult = null

        if (pending == null) return true

        // Check if all were granted
        val allGranted = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        if (allGranted) {
            // Permissions granted — proceed with scan
            doStartScan(pending)
        } else {
            pending.error("PERMISSION_DENIED", "Bluetooth permissions were denied by the user", null)
        }
        return true
    }

    // ---- Initialization ----

    private fun initBluetoothManager() {
        val ctx = activity ?: applicationContext ?: return
        btAdapter = BluetoothAdapter.getDefaultAdapter()
        bluetoothManager = BluetoothManager(ctx)
        bluetoothManager?.setCallback(object : Callback {
            override fun openPrinterResult(result: Boolean) {
                isConnected = result
                mainHandler.post {
                    if (result) {
                        connectionEventSink?.success("connected")
                    } else {
                        connectionEventSink?.success("disconnected")
                    }
                }
            }

            override fun closePrinterResult(result: Boolean) {
                isConnected = false
                mainHandler.post {
                    connectionEventSink?.success("disconnected")
                }
            }

            override fun getStatusResult(status: Int) {
                Log.d(TAG, "Status callback: $status")
            }

            override fun doPrintImagesResult(result: Boolean) {
                Log.d(TAG, "Print images result: $result")
            }

            override fun doPrintTextsResult(result: Boolean) {
                Log.d(TAG, "Print texts result: $result")
            }
        })
    }

    private fun cleanup() {
        try {
            unregisterReceiver()
            bluetoothManager?.closePrinter()
            bluetoothManager?.onDestroy()
        } catch (e: Exception) {
            Log.w(TAG, "Cleanup error: ${e.message}")
        }
        bluetoothManager = null
        btAdapter = null
        isConnected = false
        discoveredDevices.clear()
    }

    // ---- MethodCallHandler ----

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "startScan" -> handleStartScan(result)
            "stopScan" -> handleStopScan(result)
            "connect" -> handleConnect(call, result)
            "disconnect" -> handleDisconnect(result)
            "getStatus" -> handleGetStatus(result)
            "print" -> handlePrint(call, result)
            "cancelPrint" -> {
                // Not supported on Android SDK
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    // ---- Scan ----

    private fun handleStartScan(result: Result) {
        // Check and request permissions first
        if (requestPermissionsIfNeeded(result)) {
            // Permission request launched; result will be delivered in onRequestPermissionsResult
            return
        }
        doStartScan(result)
    }

    private fun doStartScan(result: Result) {
        val adapter = btAdapter
        if (adapter == null) {
            result.error("BLUETOOTH_UNAVAILABLE", "Bluetooth adapter not available", null)
            return
        }

        discoveredDevices.clear()
        registerReceiver()

        try {
            if (adapter.isDiscovering) {
                adapter.cancelDiscovery()
            }
            adapter.startDiscovery()
            result.success(null)
        } catch (e: SecurityException) {
            Log.e(TAG, "SecurityException during scan", e)
            result.error("PERMISSION_DENIED", e.message, null)
        }
    }

    private fun handleStopScan(result: Result) {
        try {
            btAdapter?.cancelDiscovery()
        } catch (e: SecurityException) {
            Log.w(TAG, "SecurityException stopping scan: ${e.message}")
        }
        unregisterReceiver()
        result.success(null)
    }

    private fun registerReceiver() {
        if (bluetoothReceiver != null) return

        val ctx = activity ?: applicationContext ?: return

        bluetoothReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                val action = intent?.action ?: return
                if (BluetoothDevice.ACTION_FOUND == action) {
                    val device: BluetoothDevice? =
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
                        } else {
                            @Suppress("DEPRECATION")
                            intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                        }
                    device ?: return

                    val name: String? = try {
                        device.name
                    } catch (e: SecurityException) {
                        null
                    }
                    if (name.isNullOrEmpty()) return

                    val address = device.address ?: return
                    val rssi = intent.getShortExtra(BluetoothDevice.EXTRA_RSSI, Short.MIN_VALUE).toInt()

                    if (!discoveredDevices.containsKey(address)) {
                        discoveredDevices[address] = device
                        mainHandler.post {
                            scanEventSink?.success(mapOf(
                                "id" to address,
                                "name" to name,
                                "rssi" to rssi,
                            ))
                        }
                    }
                }
            }
        }

        val filter = IntentFilter().apply {
            addAction(BluetoothAdapter.ACTION_DISCOVERY_STARTED)
            addAction(BluetoothDevice.ACTION_FOUND)
            addAction(BluetoothAdapter.ACTION_DISCOVERY_FINISHED)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ctx.registerReceiver(bluetoothReceiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            ctx.registerReceiver(bluetoothReceiver, filter)
        }
    }

    private fun unregisterReceiver() {
        val ctx = activity ?: applicationContext
        if (bluetoothReceiver != null && ctx != null) {
            try {
                ctx.unregisterReceiver(bluetoothReceiver)
            } catch (e: Exception) {
                Log.w(TAG, "Unregister receiver: ${e.message}")
            }
            bluetoothReceiver = null
        }
    }

    // ---- Connect ----

    private fun handleConnect(call: MethodCall, result: Result) {
        val deviceId = call.argument<String>("deviceId")
        val bypassWhitelist = call.argument<Boolean>("bypassWhitelist") ?: false

        if (deviceId == null) {
            result.error("INVALID_ARGUMENT", "deviceId is required", null)
            return
        }

        val mgr = bluetoothManager
        if (mgr == null) {
            result.error("NOT_INITIALIZED", "BluetoothManager not initialized", null)
            return
        }

        // Stop discovery before connecting
        try {
            btAdapter?.cancelDiscovery()
        } catch (_: SecurityException) {}

        val device = discoveredDevices[deviceId]
            ?: btAdapter?.getRemoteDevice(deviceId)

        if (device == null) {
            result.error("DEVICE_NOT_FOUND", "Device $deviceId not found", null)
            return
        }

        mainHandler.post {
            connectionEventSink?.success("connecting")
        }

        val connected = mgr.openPrinter(device)

        if (connected) {
            result.success(true)
            return
        }

        if (!bypassWhitelist) {
            result.success(false)
            return
        }

        // Bypass whitelist via reflection (same approach as the original Demo)
        try {
            val bluetoothUtilsField: Field = BluetoothManager::class.java.getDeclaredField("mBluetoothUtils")
            bluetoothUtilsField.isAccessible = true
            val bluetoothUtils = bluetoothUtilsField.get(mgr)

            val connectMethod: Method = bluetoothUtils.javaClass.getDeclaredMethod("a", BluetoothDevice::class.java)
            connectMethod.isAccessible = true
            connectMethod.invoke(bluetoothUtils, device)

            val printClass = Class.forName("a.a.a.d.e")
            val basePrint = printClass.getDeclaredConstructor().newInstance()

            val utilsClass = Class.forName("a.a.a.d.b")
            val basePrintClass = Class.forName("a.a.a.d.a")
            val setUtilsMethod: Method = basePrintClass.getDeclaredMethod("a", utilsClass)
            setUtilsMethod.isAccessible = true
            setUtilsMethod.invoke(basePrint, bluetoothUtils)

            val basePrintField: Field = BluetoothManager::class.java.getDeclaredField("baseParameterPrint")
            basePrintField.isAccessible = true
            basePrintField.set(mgr, basePrint)

            Log.d(TAG, "Reflection bypass connection initiated")
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Reflection bypass failed", e)
            result.error("CONNECT_BYPASS_FAILED", e.message, null)
        }
    }

    // ---- Disconnect ----

    private fun handleDisconnect(result: Result) {
        val mgr = bluetoothManager
        if (mgr == null) {
            result.success(false)
            return
        }
        mainHandler.post {
            connectionEventSink?.success("disconnecting")
        }
        mgr.closePrinter()
        result.success(true)
    }

    // ---- Status ----

    private fun handleGetStatus(result: Result) {
        val mgr = bluetoothManager
        if (mgr == null || !isConnected) {
            result.error("NOT_CONNECTED", "Printer not connected", null)
            return
        }
        val status = mgr.status
        result.success(status)
    }

    // ---- Print ----

    @Suppress("UNCHECKED_CAST")
    private fun handlePrint(call: MethodCall, result: Result) {
        val mgr = bluetoothManager
        if (mgr == null || !isConnected) {
            result.error("NOT_CONNECTED", "Printer not connected", null)
            return
        }

        try {
            val labelWidth = call.argument<Int>("labelWidth") ?: 40
            val labelHeight = call.argument<Int>("labelHeight") ?: 30
            val copies = call.argument<Int>("copies") ?: 1
            val density = call.argument<Int>("density") ?: 3
            val rotate = call.argument<Int>("rotate") ?: 0
            val horizontalOffset = call.argument<Int>("horizontalOffset") ?: 0
            val verticalOffset = call.argument<Int>("verticalOffset") ?: 0
            val paperType = call.argument<Int>("paperType") ?: 1
            val gap = call.argument<Int>("gap") ?: 3
            val oneByOne = call.argument<Boolean>("oneByOne") ?: true
            val tailLength = call.argument<Int>("tailLength") ?: 0
            val pagesData = call.argument<List<Map<String, Any>>>("pages") ?: emptyList()

            val printPages = mutableListOf<PrintPage>()
            val printImages = arrayListOf<Bitmap>()
            var hasDrawObjects = false

            for (pageData in pagesData) {
                val pageWidth = (pageData["width"] as? Int) ?: labelWidth
                val pageHeight = (pageData["height"] as? Int) ?: labelHeight
                val repeat = (pageData["repeat"] as? Int) ?: 1
                val itemsData = (pageData["items"] as? List<Map<String, Any>>) ?: emptyList()

                if (itemsData.isEmpty()) {
                    // No draw objects - will use image printing
                    printPages.add(PrintPage(pageWidth, pageHeight, repeat, null))
                } else {
                    hasDrawObjects = true
                    val drawObjects = mutableListOf<DrawObject>()

                    for (item in itemsData) {
                        val format = item["format"] as? String ?: "TEXT"
                        val x = (item["x"] as? Number)?.toInt() ?: 0
                        val y = (item["y"] as? Number)?.toInt() ?: 0
                        val width = (item["width"] as? Number)?.toInt() ?: 10
                        val height = (item["height"] as? Number)?.toInt() ?: 5
                        val content = item["content"] as? String ?: ""
                        val fontSize = (item["fontSize"] as? Number)?.toInt() ?: 3
                        val fontStyle = (item["fontStyle"] as? Number)?.toInt() ?: 0
                        val fontName = item["fontName"] as? String ?: ""
                        val antiColor = item["antiColor"] as? Boolean ?: false

                        var bitmap: Bitmap? = null
                        if (format == "IMAGE") {
                            val imageBytes = item["imageBytes"] as? ByteArray
                            if (imageBytes != null) {
                                bitmap = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size)
                            }
                        }

                        val drawObject = DrawObject(
                            antiColor,
                            x, y, width, height,
                            content,
                            fontName.ifEmpty { "黑体" },
                            fontStyle,
                            fontSize,
                            false, // autoReturn
                            format,
                            bitmap
                        )
                        drawObjects.add(drawObject)
                    }

                    printPages.add(PrintPage(pageWidth, pageHeight, repeat, drawObjects))
                }
            }

            val printParameter = PrintParameter(
                labelWidth, labelHeight, copies, rotate,
                density, horizontalOffset, verticalOffset,
                paperType, gap, oneByOne, tailLength,
                printPages
            )

            val printResult: Boolean = if (hasDrawObjects) {
                mgr.doPrintParameter(printParameter)
            } else if (printImages.isNotEmpty()) {
                mgr.doPrintImage(printImages, printParameter)
            } else {
                mgr.doPrintParameter(printParameter)
            }

            result.success(printResult)
        } catch (e: Exception) {
            Log.e(TAG, "Print error", e)
            result.error("PRINT_ERROR", e.message, null)
        }
    }
}
