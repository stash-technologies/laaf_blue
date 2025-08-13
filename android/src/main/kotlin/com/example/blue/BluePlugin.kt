package com.example.blue

import android.Manifest
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry

/** BluePlugin */
class BluePlugin: FlutterPlugin, MethodCallHandler, ActivityAware, PluginRegistry.RequestPermissionsResultListener {
    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private lateinit var channel : MethodChannel
    private lateinit var context: Context
    private var activity: Activity? = null
    private lateinit var bluetoothManager: BluetoothManagerWrapper
    
    companion object {
        private const val PERMISSION_REQUEST_CODE = 1001
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "blue")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
        bluetoothManager = BluetoothManagerWrapper(context, channel)
    }

    // Legacy registration method for older Flutter versions
    fun onAttachedToEngine(messenger: BinaryMessenger, context: Context) {
        channel = MethodChannel(messenger, "blue")
        channel.setMethodCallHandler(this)
        this.context = context
        bluetoothManager = BluetoothManagerWrapper(context, channel)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initializeBluetooth" -> {
                val uuids = call.arguments as? List<String>
                initializeBluetooth(uuids, result)
            }
            "scan" -> {
                val duration = call.arguments as? Int ?: 10000
                scan(duration, result)
            }
            "stopScan" -> {
                stopScan(result)
            }
            "connect" -> {
                val deviceId = call.arguments as? String
                if (deviceId != null) {
                    connect(deviceId, result)
                } else {
                    result.error("INVALID_ARGUMENT", "Device ID is required", null)
                }
            }
            "disconnect" -> {
                val deviceId = call.arguments as? String
                if (deviceId != null) {
                    disconnect(deviceId, result)
                } else {
                    result.error("INVALID_ARGUMENT", "Device ID is required", null)
                }
            }
            "checkMode" -> {
                val deviceId = call.arguments as? String
                if (deviceId != null) {
                    checkMode(deviceId, result)
                } else {
                    result.error("INVALID_ARGUMENT", "Device ID is required", null)
                }
            }
            "sendCommand" -> {
                val args = call.arguments as? Map<String, Any>
                val deviceId = args?.get("device") as? String
                val command = args?.get("command") as? ByteArray
                if (deviceId != null && command != null) {
                    sendCommand(deviceId, command, result)
                } else {
                    result.error("INVALID_ARGUMENT", "Device ID and command are required", null)
                }
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun initializeBluetooth(uuids: List<String>?, result: Result) {
        if (!hasBluetoothPermissions()) {
            requestBluetoothPermissions()
            result.error("PERMISSION_DENIED", "Bluetooth permissions not granted", null)
            return
        }

        val bluetoothAdapter = getBluetoothAdapter()
        if (bluetoothAdapter == null) {
            result.error("BLUETOOTH_NOT_AVAILABLE", "Bluetooth not available on this device", null)
            return
        }

        if (!bluetoothAdapter.isEnabled) {
            result.error("BLUETOOTH_DISABLED", "Bluetooth is not enabled", null)
            return
        }

        bluetoothManager.initialize(uuids ?: emptyList())
        result.success(true)
    }

    private fun scan(duration: Int, result: Result) {
        if (!hasBluetoothPermissions()) {
            result.error("PERMISSION_DENIED", "Bluetooth permissions not granted", null)
            return
        }

        bluetoothManager.startScan(duration, result)
    }

    private fun stopScan(result: Result) {
        bluetoothManager.stopScan(result)
    }

    private fun connect(deviceId: String, result: Result) {
        bluetoothManager.connect(deviceId, result)
    }

    private fun disconnect(deviceId: String, result: Result) {
        bluetoothManager.disconnect(deviceId, result)
    }

    private fun checkMode(deviceId: String, result: Result) {
        bluetoothManager.checkMode(deviceId, result)
    }

    private fun sendCommand(deviceId: String, command: ByteArray, result: Result) {
        bluetoothManager.sendCommand(deviceId, command, result)
    }

    private fun getBluetoothAdapter(): BluetoothAdapter? {
        val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        return bluetoothManager.adapter
    }

    private fun hasBluetoothPermissions(): Boolean {
        val permissions = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.BLUETOOTH_CONNECT,
                Manifest.permission.ACCESS_FINE_LOCATION
            )
        } else {
            arrayOf(
                Manifest.permission.BLUETOOTH,
                Manifest.permission.BLUETOOTH_ADMIN,
                Manifest.permission.ACCESS_FINE_LOCATION
            )
        }

        return permissions.all { permission ->
            ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun requestBluetoothPermissions() {
        activity?.let { activity ->
            val permissions = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                arrayOf(
                    Manifest.permission.BLUETOOTH_SCAN,
                    Manifest.permission.BLUETOOTH_CONNECT,
                    Manifest.permission.ACCESS_FINE_LOCATION
                )
            } else {
                arrayOf(
                    Manifest.permission.BLUETOOTH,
                    Manifest.permission.BLUETOOTH_ADMIN,
                    Manifest.permission.ACCESS_FINE_LOCATION
                )
            }

            ActivityCompat.requestPermissions(activity, permissions, PERMISSION_REQUEST_CODE)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        if (requestCode == PERMISSION_REQUEST_CODE) {
            val allGranted = grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            if (allGranted) {
                // Permissions granted, can proceed with Bluetooth operations
                channel.invokeMethod("bluetoothPermissionsGranted", null)
            } else {
                // Permissions denied
                channel.invokeMethod("bluetoothPermissionsDenied", null)
            }
            return true
        }
        return false
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        bluetoothManager.cleanup()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }
}
