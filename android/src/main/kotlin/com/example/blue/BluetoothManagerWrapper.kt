package com.example.blue

import android.bluetooth.*
import android.bluetooth.le.*
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import java.util.*
import kotlin.collections.HashMap

class BluetoothManagerWrapper(
    private val context: Context,
    private val channel: MethodChannel
) {
    private val bluetoothManager: BluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
    private val bluetoothAdapter: BluetoothAdapter? = bluetoothManager.adapter
    private val bluetoothLeScanner: BluetoothLeScanner? = bluetoothAdapter?.bluetoothLeScanner
    private val handler = Handler(Looper.getMainLooper())
    
    private val connectedDevices = HashMap<String, LFLinerDevice>()
    private val scannedDevices = HashMap<String, BluetoothDevice>()
    private var isScanning = false
    private var scanCallback: ScanCallback? = null
    
    // LAAF Service and Characteristic UUIDs
    private lateinit var serviceUuid: UUID
    private lateinit var commandCharUuid: UUID
    private lateinit var dataCharUuid: UUID
    private lateinit var modeCharUuid: UUID
    private lateinit var liveStreamCharUuid: UUID

    companion object {
        private const val TAG = "BluetoothManagerWrapper"
    }

    fun initialize(uuids: List<String>) {
        if (uuids.size >= 5) {
            serviceUuid = UUID.fromString(uuids[0])
            commandCharUuid = UUID.fromString(uuids[1])
            dataCharUuid = UUID.fromString(uuids[2])
            modeCharUuid = UUID.fromString(uuids[3])
            liveStreamCharUuid = UUID.fromString(uuids[4])
            
            Log.d(TAG, "Initialized with UUIDs: service=${serviceUuid}, command=${commandCharUuid}")
        } else {
            Log.e(TAG, "Insufficient UUIDs provided for initialization")
        }
        
        // Notify Flutter about initial Bluetooth state
        notifyBluetoothState()
    }

    fun startScan(duration: Int, result: MethodChannel.Result) {
        if (isScanning) {
            result.success(false)
            return
        }

        if (bluetoothLeScanner == null) {
            result.error("BLUETOOTH_UNAVAILABLE", "Bluetooth LE scanner not available", null)
            return
        }

        scannedDevices.clear()
        isScanning = true

        val scanSettings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .setCallbackType(ScanSettings.CALLBACK_TYPE_ALL_MATCHES)
            .build()

        val scanFilters = listOf(
            ScanFilter.Builder()
                .setServiceUuid(ParcelUuid(serviceUuid))
                .build()
        )

        scanCallback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                val device = result.device
                val deviceId = device.address
                
                if (!scannedDevices.containsKey(deviceId)) {
                    scannedDevices[deviceId] = device
                    Log.d(TAG, "Found device: ${device.name ?: "Unknown"} (${deviceId})")
                    updateScannedDevices()
                }
            }

            override fun onScanFailed(errorCode: Int) {
                Log.e(TAG, "Scan failed with error code: $errorCode")
                isScanning = false
                channel.invokeMethod("flutterMessage", mapOf(
                    "id" to "general",
                    "message" to "Scan failed with error code: $errorCode"
                ))
            }
        }

        try {
            bluetoothLeScanner?.startScan(scanFilters, scanSettings, scanCallback)
            result.success(true)
            
            // Stop scan after duration
            handler.postDelayed({
                stopScan(null)
            }, duration.toLong())
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start scan", e)
            isScanning = false
            result.error("SCAN_FAILED", "Failed to start scan: ${e.message}", null)
        }
    }

    fun stopScan(result: MethodChannel.Result?) {
        if (!isScanning) {
            result?.success(false)
            return
        }

        try {
            scanCallback?.let { callback ->
                bluetoothLeScanner?.stopScan(callback)
            }
            isScanning = false
            result?.success(true)
            Log.d(TAG, "Scan stopped")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop scan", e)
            result?.error("STOP_SCAN_FAILED", "Failed to stop scan: ${e.message}", null)
        }
    }

    fun connect(deviceId: String, result: MethodChannel.Result) {
        val bluetoothDevice = scannedDevices[deviceId] ?: bluetoothAdapter?.getRemoteDevice(deviceId)
        
        if (bluetoothDevice == null) {
            result.error("DEVICE_NOT_FOUND", "Device not found: $deviceId", null)
            return
        }

        if (connectedDevices.containsKey(deviceId)) {
            result.error("ALREADY_CONNECTED", "Device already connected: $deviceId", null)
            return
        }

        val lfLinerDevice = LFLinerDevice(
            bluetoothDevice,
            channel,
            serviceUuid,
            commandCharUuid,
            dataCharUuid,
            modeCharUuid,
            liveStreamCharUuid
        )

        connectedDevices[deviceId] = lfLinerDevice
        lfLinerDevice.connect(result)
    }

    fun disconnect(deviceId: String, result: MethodChannel.Result) {
        val device = connectedDevices[deviceId]
        if (device == null) {
            result.error("DEVICE_NOT_CONNECTED", "Device not connected: $deviceId", null)
            return
        }

        device.disconnect()
        connectedDevices.remove(deviceId)
        result.success(true)
    }

    fun checkMode(deviceId: String, result: MethodChannel.Result) {
        val device = connectedDevices[deviceId]
        if (device == null) {
            result.error("DEVICE_NOT_CONNECTED", "Device not connected: $deviceId", null)
            return
        }

        device.checkMode(result)
    }

    fun sendCommand(deviceId: String, command: ByteArray, result: MethodChannel.Result) {
        val device = connectedDevices[deviceId]
        if (device == null) {
            result.error("DEVICE_NOT_CONNECTED", "Device not connected: $deviceId", null)
            return
        }

        device.sendCommand(command, result)
    }

    private fun updateScannedDevices() {
        val deviceList = scannedDevices.values.map { device ->
            mapOf(
                "id" to device.address,
                "name" to (device.name ?: "Unknown Device"),
                "rssi" to 0 // RSSI not available in this context
            )
        }
        
        channel.invokeMethod("updateDetectedDevices", deviceList)
    }

    private fun notifyBluetoothState() {
        val state = when {
            bluetoothAdapter == null -> 0 // unavailable
            !bluetoothAdapter.isEnabled -> 1 // disabled
            else -> 2 // available
        }
        
        channel.invokeMethod("bluetoothStateUpdate", state)
    }

    fun cleanup() {
        stopScan(null)
        connectedDevices.values.forEach { it.disconnect() }
        connectedDevices.clear()
    }
}
