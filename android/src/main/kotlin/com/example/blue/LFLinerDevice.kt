package com.example.blue

import android.bluetooth.*
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import java.util.*

class LFLinerDevice(
    private val bluetoothDevice: BluetoothDevice,
    private val channel: MethodChannel,
    private val serviceUuid: UUID,
    private val commandCharUuid: UUID,
    private val dataCharUuid: UUID,
    private val modeCharUuid: UUID,
    private val liveStreamCharUuid: UUID
) {
    private var bluetoothGatt: BluetoothGatt? = null
    private var commandCharacteristic: BluetoothGattCharacteristic? = null
    private var dataCharacteristic: BluetoothGattCharacteristic? = null
    private var modeCharacteristic: BluetoothGattCharacteristic? = null
    private var liveStreamCharacteristic: BluetoothGattCharacteristic? = null
    
    private val handler = Handler(Looper.getMainLooper())
    private var connectionResult: MethodChannel.Result? = null
    private var commandResult: MethodChannel.Result? = null
    
    private var connectionProgress = ConnectionProgress()

    companion object {
        private const val TAG = "LFLinerDevice"
    }

    private data class ConnectionProgress(
        var dataCharNotificationEnabled: Boolean = false,
        var modeCharNotificationEnabled: Boolean = false,
        var liveStreamCharNotificationEnabled: Boolean = false
    ) {
        fun isComplete(): Boolean = dataCharNotificationEnabled && modeCharNotificationEnabled && liveStreamCharNotificationEnabled
        fun reset() {
            dataCharNotificationEnabled = false
            modeCharNotificationEnabled = false
            liveStreamCharNotificationEnabled = false
        }
    }

    private val gattCallback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            when (newState) {
                BluetoothProfile.STATE_CONNECTED -> {
                    Log.d(TAG, "Connected to GATT server for ${bluetoothDevice.address}")
                    flutterMessage("Connected to device, discovering services...")
                    gatt.discoverServices()
                }
                BluetoothProfile.STATE_DISCONNECTED -> {
                    Log.d(TAG, "Disconnected from GATT server for ${bluetoothDevice.address}")
                    flutterMessage("Device disconnected")
                    channel.invokeMethod("deviceDisconnected", bluetoothDevice.address)
                    cleanup()
                }
            }
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                Log.d(TAG, "Services discovered for ${bluetoothDevice.address}")
                setupCharacteristics(gatt)
            } else {
                Log.e(TAG, "Service discovery failed with status: $status")
                connectionResult?.error("SERVICE_DISCOVERY_FAILED", "Failed to discover services", null)
                connectionResult = null
            }
        }

        override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
            val data = characteristic.value
            if (data != null) {
                when (characteristic.uuid) {
                    modeCharUuid -> {
                        // Device state update
                        val deviceState = data[0].toInt()
                        flutterMessage("Device state updated: $deviceState")
                        channel.invokeMethod("updateDeviceState", mapOf(
                            "id" to bluetoothDevice.address,
                            "state" to deviceState
                        ))
                    }
                    liveStreamCharUuid -> {
                        // Live stream data packet
                        channel.invokeMethod("liveStreamPacket", mapOf(
                            "id" to bluetoothDevice.address,
                            "packet" to data
                        ))
                    }
                    dataCharUuid -> {
                        // Handle LAAF protocol file management responses
                        handleDataCharacteristicResponse(data)
                    }
                }
            }
        }

        override fun onCharacteristicWrite(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
            val value = characteristic.value?.let { bytes ->
                bytes.joinToString("") { "%02x".format(it) }
            } ?: "nil"
            
            flutterMessage("Command written to ${parseCharacteristic(characteristic)}: $value")
            
            if (characteristic.uuid == commandCharUuid) {
                commandResult?.success(status == BluetoothGatt.GATT_SUCCESS)
                commandResult = null
            }
        }

        override fun onDescriptorWrite(gatt: BluetoothGatt, descriptor: BluetoothGattDescriptor, status: Int) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                val characteristic = descriptor.characteristic
                when (characteristic.uuid) {
                    dataCharUuid -> {
                        connectionProgress.dataCharNotificationEnabled = true
                        flutterMessage("Data characteristic notifications enabled")
                    }
                    modeCharUuid -> {
                        connectionProgress.modeCharNotificationEnabled = true
                        flutterMessage("Mode characteristic notifications enabled")
                    }
                    liveStreamCharUuid -> {
                        connectionProgress.liveStreamCharNotificationEnabled = true
                        flutterMessage("Live stream characteristic notifications enabled")
                    }
                }
                
                if (connectionProgress.isComplete()) {
                    flutterMessage("All notifications enabled, connection complete")
                    channel.invokeMethod("connectionComplete", bluetoothDevice.address)
                    connectionResult?.success(true)
                    connectionResult = null
                }
            } else {
                Log.e(TAG, "Failed to enable notifications for ${descriptor.characteristic.uuid}")
                connectionResult?.error("NOTIFICATION_SETUP_FAILED", "Failed to enable notifications", null)
                connectionResult = null
            }
        }
    }

    fun connect(result: MethodChannel.Result) {
        connectionResult = result
        connectionProgress.reset()
        
        try {
            bluetoothGatt = bluetoothDevice.connectGatt(null, false, gattCallback)
            if (bluetoothGatt == null) {
                result.error("CONNECTION_FAILED", "Failed to create GATT connection", null)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to connect to device", e)
            result.error("CONNECTION_FAILED", "Failed to connect: ${e.message}", null)
        }
    }

    fun disconnect() {
        bluetoothGatt?.disconnect()
        cleanup()
    }

    fun checkMode(result: MethodChannel.Result) {
        modeCharacteristic?.let { characteristic ->
            bluetoothGatt?.readCharacteristic(characteristic)
            result.success(true)
        } ?: result.error("CHARACTERISTIC_NOT_FOUND", "Mode characteristic not found", null)
    }

    fun sendCommand(command: ByteArray, result: MethodChannel.Result) {
        commandCharacteristic?.let { characteristic ->
            commandResult = result
            characteristic.value = command
            val success = bluetoothGatt?.writeCharacteristic(characteristic) ?: false
            if (!success) {
                commandResult = null
                result.error("WRITE_FAILED", "Failed to write command", null)
            }
        } ?: result.error("CHARACTERISTIC_NOT_FOUND", "Command characteristic not found", null)
    }

    private fun setupCharacteristics(gatt: BluetoothGatt) {
        val service = gatt.getService(serviceUuid)
        if (service == null) {
            Log.e(TAG, "LAAF service not found")
            connectionResult?.error("SERVICE_NOT_FOUND", "LAAF service not found", null)
            connectionResult = null
            return
        }

        // Get characteristics
        commandCharacteristic = service.getCharacteristic(commandCharUuid)
        dataCharacteristic = service.getCharacteristic(dataCharUuid)
        modeCharacteristic = service.getCharacteristic(modeCharUuid)
        liveStreamCharacteristic = service.getCharacteristic(liveStreamCharUuid)

        // Enable notifications for data, mode, and live stream characteristics
        enableNotifications(gatt, dataCharacteristic, "data")
        enableNotifications(gatt, modeCharacteristic, "mode")
        enableNotifications(gatt, liveStreamCharacteristic, "live stream")
    }

    private fun enableNotifications(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic?, name: String) {
        if (characteristic == null) {
            Log.e(TAG, "$name characteristic not found")
            connectionResult?.error("CHARACTERISTIC_NOT_FOUND", "$name characteristic not found", null)
            connectionResult = null
            return
        }

        val success = gatt.setCharacteristicNotification(characteristic, true)
        if (!success) {
            Log.e(TAG, "Failed to enable notifications for $name characteristic")
            connectionResult?.error("NOTIFICATION_SETUP_FAILED", "Failed to enable $name notifications", null)
            connectionResult = null
            return
        }

        // Write to descriptor to enable notifications
        val descriptor = characteristic.getDescriptor(UUID.fromString("00002902-0000-1000-8000-00805f9b34fb"))
        if (descriptor != null) {
            descriptor.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
            gatt.writeDescriptor(descriptor)
        } else {
            Log.e(TAG, "Notification descriptor not found for $name characteristic")
            connectionResult?.error("DESCRIPTOR_NOT_FOUND", "Notification descriptor not found for $name", null)
            connectionResult = null
        }
    }

    private fun handleDataCharacteristicResponse(data: ByteArray) {
        if (data.isEmpty()) return
        
        val commandId = data[0].toUByte().toInt()
        val dataHex = data.joinToString("") { "%02x".format(it) }
        flutterMessage("Data characteristic received: [$dataHex] (command: 0x${"%02x".format(commandId)})")
        
        when (commandId) {
            0x20 -> { // Response to "get number of files" command
                if (data.size >= 2) {
                    val fileCount = data[1].toUByte().toInt()
                    flutterMessage("Device has $fileCount files")
                    channel.invokeMethod("fileCountResponse", mapOf(
                        "id" to bluetoothDevice.address,
                        "count" to fileCount
                    ))
                } else {
                    flutterMessage("Invalid file count response format")
                }
            }
            
            0x21 -> { // Response to "get file" command - file data chunk
                if (data.size > 1) {
                    val fileData = data.sliceArray(1 until data.size)
                    flutterMessage("Received file data chunk (${fileData.size} bytes)")
                    channel.invokeMethod("fileDataChunk", mapOf(
                        "id" to bluetoothDevice.address,
                        "chunk" to fileData,
                        "isComplete" to false // You may need to determine this based on your protocol
                    ))
                }
            }
            
            0x10 -> { // Response to "get summary file" command
                if (data.size > 1) {
                    val summaryData = data.sliceArray(1 until data.size)
                    flutterMessage("Received summary file (${summaryData.size} bytes)")
                    channel.invokeMethod("summaryFileResponse", mapOf(
                        "id" to bluetoothDevice.address,
                        "data" to summaryData
                    ))
                }
            }
            
            0x22, 0x29 -> { // Response to erase file commands
                val success = if (data.size > 1) data[1].toInt() == 0x01 else true
                val operation = if (commandId == 0x22) "eraseFile" else "eraseAllFiles"
                flutterMessage("File operation $operation: ${if (success) "success" else "failed"}")
                channel.invokeMethod("fileOperationComplete", mapOf(
                    "id" to bluetoothDevice.address,
                    "operation" to operation,
                    "success" to success
                ))
            }
            
            0x01, 0x02 -> { // Response to start/stop logging commands
                val isLogging = commandId == 0x01
                val dataTypes = if (data.size > 1) data[1].toInt() else 0
                
                // Validate data types - only accept valid LAAF protocol flags
                val validDataTypes = listOf(0, 1, 2, 3, 4, 5, 6, 7) // Valid combinations of Step(1), IMU(2), FSR(4)
                
                if (isLogging && !validDataTypes.contains(dataTypes)) {
                    flutterMessage("Invalid data type flags: $dataTypes - ignoring spurious logging command")
                    return
                }
                
                // Only process if this looks like a legitimate command response
                // Real logging responses should be short (2-3 bytes max)
                if (data.size > 3) {
                    flutterMessage("Logging response too long (${data.size} bytes) - likely sensor data, ignoring")
                    return
                }
                
                flutterMessage("Logging status update: ${if (isLogging) "started" else "stopped"} with data types: $dataTypes")
                channel.invokeMethod("loggingStatusUpdate", mapOf(
                    "id" to bluetoothDevice.address,
                    "isLogging" to isLogging,
                    "dataTypes" to dataTypes
                ))
            }
            
            0xD5, 0xE0, 0xD0 -> {
                // These are sensor data packets, not file management responses
                flutterMessage("Ignoring sensor data packet: 0x${"%02x".format(commandId)}")
            }
            
            else -> {
                flutterMessage("Unknown command response: 0x${"%02x".format(commandId)}")
            }
        }
    }

    private fun parseCharacteristic(characteristic: BluetoothGattCharacteristic): String {
        return when (characteristic.uuid) {
            commandCharUuid -> "command"
            dataCharUuid -> "data"
            modeCharUuid -> "mode"
            liveStreamCharUuid -> "live_stream"
            else -> "unknown"
        }
    }

    private fun flutterMessage(message: String) {
        Log.d(TAG, "Device ${bluetoothDevice.address}: $message")
        channel.invokeMethod("flutterMessage", mapOf(
            "id" to bluetoothDevice.address,
            "message" to message
        ))
    }

    private fun cleanup() {
        bluetoothGatt?.close()
        bluetoothGatt = null
        commandCharacteristic = null
        dataCharacteristic = null
        modeCharacteristic = null
        liveStreamCharacteristic = null
        connectionResult = null
        commandResult = null
    }
}
