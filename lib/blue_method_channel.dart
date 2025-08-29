import 'dart:async';

import 'package:blue/step_data_packet.dart';
import 'package:flutter/services.dart';

import 'blue_platform_interface.dart';
import 'blue_state.dart';
import 'bluetooth_status.dart';
import 'device_state.dart';
import 'lf_liner.dart';
import 'logger.dart';
import 'step.dart';

/// An implementation of [BluePlatform] that uses method channels.
class MethodChannelBlue extends BluePlatform {
  /// The method channel used to interact with the native platform.
  //@visibleForTesting
  final methodChannel = const MethodChannel('blue');

  final blueState = BlueState();

  MethodChannelBlue() {
    try {
      methodChannel.setMethodCallHandler(methodHandler);
    } catch (e) {
      Logger.log("b error", "Constructor error: $e");
    }
  }

  @override
  BlueState getBlueState() {
    try {
      return blueState;
    } catch (e) {
      Logger.log("b error", "Get blue state error: $e");
      return BlueState();
    }
  }

  @override
  Future<bool?> initializeBluetooth() async {
    try {
      final uuids = [
        "00008801-0000-1000-8000-00805f9b34fb", // general service uuid
        "00008811-0000-1000-8000-00805f9b34fb", // command char uuid
        "00008812-0000-1000-8000-00805f9b34fb", // data char uuid
        "00008813-0000-1000-8000-00805f9b34fb", // mode char uuid
        "0000880E-0000-1000-8000-00805f9b34fb" // live stream data uuid
      ];
      final result = await methodChannel.invokeMethod<bool>('initializeBluetooth', uuids);

      return result;
    } catch (e) {
      Logger.log("b error", "Initialize bluetooth error: $e");
      return false;
    }
  }

  @override
  Future<bool?> scan(int duration) async {
    try {
      final scanResult = await methodChannel.invokeMethod<bool?>('scan', duration);

      if (scanResult!) {
        Logger.log("b", "updating bluestate scanning status...");
        blueState.scanning.update(true);
      } else {
        Logger.log("b", "you are already scanning...");
        return Future<bool?>(() => false);
      }

      await Future.delayed(Duration(milliseconds: duration));

      final stopScanResult = await methodChannel.invokeMethod<bool?>('stopScan');

      blueState.scanning.update(!stopScanResult!);

      return stopScanResult;
    } catch (e) {
      Logger.log("b error", "Scan error: $e");
      blueState.scanning.update(false);
      return false;
    }
  }

  @override
  Future<bool?> stopScan() async {
    try {
      if (!blueState.scanning.value()) {
        Logger.log("b warning", "a 'stopScan' was attempted when no scan was in progress");
        return Future<bool?>(() => false);
      }

      final result = await methodChannel.invokeMethod<bool?>('stopScan');

      if (result!) {
        blueState.scanning.update(false);
      } else {
        // something went wrong...
        Logger.log("b warning", "failed to 'stopScan'");
      }

      return result;
    } catch (e) {
      Logger.log("b error", "Stop scan error: $e");
      blueState.scanning.update(false);
      return false;
    }
  }

  @override
  Future<bool?> connect(String deviceId) async {
    try {
      Logger.log("b", "connecting to device $deviceId");

      final result = await methodChannel.invokeMethod<bool?>('connect', deviceId);

      return result;
    } catch (e) {
      Logger.log("b error", "Connect error for device $deviceId: $e");
      return false;
    }
  }

  @override
  Future<bool?> checkMode(String deviceId) async {
    try {
      Logger.log("b", "checking mode of device $deviceId");
      final result = await methodChannel.invokeMethod<bool?>('checkMode', deviceId);

      return result;
    } catch (e) {
      Logger.log("b error", "Check mode error for device $deviceId: $e");
      return false;
    }
  }

  List<String> devicesStagedForDisconnection = [];

  @override
  Future<bool?> disconnect(String deviceId, {bool keepAround = true}) async {
    try {
      Logger.log("b", "disconnecting device $deviceId");

      if (keepAround && !devicesStagedForDisconnection.contains(deviceId)) {
        devicesStagedForDisconnection.add(deviceId);
      }

      final result = await methodChannel.invokeMethod<bool?>('disconnect', deviceId);

      return result;
    } catch (e) {
      Logger.log("b error", "Disconnect error for device $deviceId: $e");
      return false;
    }
  }

  @override
  Future<bool?> reset(String deviceId) async {
    try {
      Logger.log("b", "resetting: $deviceId");
      final args = {
        "device": deviceId,
        "command": Uint8List.fromList([0x51])
      };
      final result = await methodChannel.invokeMethod<bool?>('sendCommand', args);

      return result;
    } catch (e) {
      Logger.log("b error", "Reset error for device $deviceId: $e");
      return false;
    }
  }

  @override
  Future<bool?> sendCommand(String deviceId, Uint8List command) async {
    try {
      Logger.log("b", "sending command $command to $deviceId");

      final args = {"device": deviceId, "command": command};
      final result = await methodChannel.invokeMethod<bool?>('sendCommand', args);

      return result;
    } catch (e) {
      Logger.log("b error", "Send command error for device $deviceId: $e");
      return false;
    }
  }

  // New LAAF protocol method implementations
  @override
  Future<bool?> setTime(String deviceId, DateTime timestamp) async {
    try {
      Logger.log("b", "setting time for device $deviceId to $timestamp");

      // Convert DateTime to Unix timestamp (seconds since epoch)
      final unixTimestamp = timestamp.millisecondsSinceEpoch ~/ 1000;

      // Create set time command with Unix timestamp (4 bytes, little-endian)
      final command = Uint8List(5);
      command[0] = 0x10; // Set time command ID
      command[1] = (unixTimestamp & 0xFF);
      command[2] = ((unixTimestamp >> 8) & 0xFF);
      command[3] = ((unixTimestamp >> 16) & 0xFF);
      command[4] = ((unixTimestamp >> 24) & 0xFF);

      return await sendCommand(deviceId, command);
    } catch (e) {
      Logger.log("b error", "Set time error for device $deviceId: $e");
      return false;
    }
  }

  @override
  Future<bool?> startLogging(String deviceId, int dataTypeFlags) async {
    try {
      Logger.log("b", "starting logging for device $deviceId with flags $dataTypeFlags");

      // Create start logging command with data type flags
      final command = Uint8List(2);
      command[0] = 0x01; // Start logging command ID
      command[1] = dataTypeFlags & 0xFF; // Data type flags (0x01=Step, 0x02=IMU, 0x04=FSR)

      return await sendCommand(deviceId, command);
    } catch (e) {
      Logger.log("b error", "Start logging error for device $deviceId: $e");
      return false;
    }
  }

  @override
  Future<bool?> stopLogging(String deviceId) async {
    try {
      Logger.log("b", "stopping logging for device $deviceId");

      // Create stop logging command
      final command = Uint8List.fromList([0x02]); // Stop logging command ID

      return await sendCommand(deviceId, command);
    } catch (e) {
      Logger.log("b error", "Stop logging error for device $deviceId: $e");
      return false;
    }
  }

  @override
  Future<int?> getNumberOfFiles(String deviceId) async {
    try {
      Logger.log("b", "getting number of files for device $deviceId");

      // Create get number of files command
      final command = Uint8List.fromList([0x20]); // Get number of files command ID

      final result = await sendCommand(deviceId, command);

      // Note: The actual file count will come back through the methodHandler
      // This method returns success/failure of sending the command
      // The file count will be updated in the device's observable
      return result == true ? 0 : null; // Placeholder - actual count comes via callback
    } catch (e) {
      Logger.log("b error", "Get number of files error for device $deviceId: $e");
      return null;
    }
  }

  @override
  Future<bool?> getFile(String deviceId, int fileIndex) async {
    try {
      Logger.log("b", "getting file $fileIndex for device $deviceId");

      // Create get file command with file index
      final command = Uint8List(2);
      command[0] = 0x21; // Get file command ID
      command[1] = fileIndex & 0xFF; // File index (1-based)

      return await sendCommand(deviceId, command);
    } catch (e) {
      Logger.log("b error", "Get file error for device $deviceId: $e");
      return false;
    }
  }

  @override
  Future<bool?> eraseFile(String deviceId, int fileIndex) async {
    try {
      Logger.log("b", "erasing file $fileIndex for device $deviceId");

      // Create erase file command with file index
      final command = Uint8List(2);
      command[0] = 0x22; // Correct erase file command ID
      command[1] = fileIndex & 0xFF; // File index (1-based)

      return await sendCommand(deviceId, command);
    } catch (e) {
      Logger.log("b error", "Erase file error for device $deviceId: $e");
      return false;
    }
  }

  @override
  Future<bool?> eraseLastFile(String deviceId) async {
    try {
      Logger.log("b", "erasing last file for device $deviceId");

      // Create erase last file command (no data bytes)
      final command = Uint8List.fromList([0x22]); // Correct erase file command ID with no index

      return await sendCommand(deviceId, command);
    } catch (e) {
      Logger.log("b error", "Erase last file error for device $deviceId: $e");
      return false;
    }
  }

  @override
  Future<bool?> eraseAllFiles(String deviceId) async {
    try {
      Logger.log("b", "erasing all files for device $deviceId");

      // Create erase all files command
      final command = Uint8List.fromList([0x29]); // Correct erase all files command ID

      return await sendCommand(deviceId, command);
    } catch (e) {
      Logger.log("b error", "Erase all files error for device $deviceId: $e");
      return false;
    }
  }

  @override
  Future<bool?> getSummaryFile(String deviceId) async {
    try {
      Logger.log("b", "getting summary file for device $deviceId");

      // Create get summary file command
      final command = Uint8List.fromList([0x10]); // Get summary file command ID

      return await sendCommand(deviceId, command);
    } catch (e) {
      Logger.log("b error", "Get summary file error for device $deviceId: $e");
      return false;
    }
  }

  LFLiner getDevice(String id) {
    try {
      return blueState.activeDevices.value().firstWhere((l) => l.id == id);
    } catch (e) {
      Logger.log("b error", "Get device error for id $id: $e");
      return LFLiner.emptyDevice();
    }
  }

  Future<void> methodHandler(MethodCall call) async {
    try {
      switch (call.method) {
      case "bluetoothStateUpdate":
        final state = BluetoothStatus.values[(call.arguments as int)];

        blueState.bluetoothStatus.update(state);
        blueState.activeDevices.update([]);

      case "flutterMessage":
        final args = call.arguments as Map;

        final id = args["id"] as String;
        final message = args["message"] as String;

        if (id != "general") {
          if (blueState.activeDevices.value().isEmpty) {
            return;
          }
          LFLiner device = getDevice(id);

          device.message.update(message);
          Logger.log("b", message);
        } else {
          blueState.blueMessage.update(message);
        }

      case "updateDetectedDevices":
        List<LFLiner> newDevices = (call.arguments as List).map((o) => LFLiner.deviceFromMap(o)).toList();
        blueState.scannedDevices.update(newDevices);

      case "connectionComplete":
        final id = call.arguments as String;

        // reset step calculator

        blueState.stepDataCalculator.reset();

        checkMode(id);

      case "updateDeviceState":
        final args = call.arguments as Map;
        final id = args["id"] as String;
        final DeviceState updatedState = DeviceState.values[args["state"] as int];
        Logger.log("b", "device state update: $id / $updatedState");

        if (blueState.activeDevices.value().isEmpty) {
          return;
        }
        final device = getDevice(id);

        // clear messages
        device.message.update("state updated...");

        device.deviceState.update(updatedState);

        if (updatedState == DeviceState.logging) {
          /// the device thinks it logging if it reset when streaming...
        }

      case "deviceDisconnected":
        final id = call.arguments as String;

        if (blueState.activeDevices.value().isEmpty) {
          return;
        }
        final device = getDevice(id);

        device.deviceState.update(DeviceState.disconnected);

        if (devicesStagedForDisconnection.contains(id)) {
          Logger.log("b", "removing device from active devices");
          devicesStagedForDisconnection.remove(id);
          final devices = blueState.activeDevices.value();
          devices.remove(device);
          blueState.activeDevices.update(devices);
        }

        Logger.log("b", "device disconnected $id");

      case "liveStreamPacket":
        final args = call.arguments as Map;
        final id = args["id"] as String;
        final packet = args["packet"] as Uint8List;

        if (blueState.activeDevices.value().isEmpty) {
          return;
        }
        final device = getDevice(id);

        if (device.liveStreamPacket.hasObservers()) {
          device.liveStreamPacket.update(packet);
        }

        if (packet[0] == 0xD5) {
          final data = StepDataPacket(packet);
          blueState.stepDataCalculator
              .addStep(Step(data.timestamp.toInt(), data.timestamp.toInt() + data.contactTime.toInt(), device.side));
        }

        device.parseAndUpdatePacket(packet);

        // check for streaming status
        if (device.deviceState.value() != DeviceState.streaming) {
          device.deviceState.update(DeviceState.streaming);
        } else {
          // invalidate the existing timer
          device.timer!.cancel();
        }
        // launch a timer to check if we have stopped streaming
        device.lastPacketTime = DateTime.now().millisecondsSinceEpoch;
        if (device.timer != null) {
          device.timer!.cancel();
        }
        device.timer = Timer(const Duration(milliseconds: 1100), () {
          liveStreamPacketTimeout(device);
        });

      // New LAAF protocol file management response handlers
      case "fileCountResponse":
        final args = call.arguments as Map;
        final id = args["id"] as String;
        final count = args["count"] as int;

        if (blueState.activeDevices.value().isEmpty) {
          return;
        }
        final device = getDevice(id);
        device.fileCount.update(count);
        Logger.log("b", "Device $id has $count files");

      case "fileDataChunk":
        final args = call.arguments as Map;
        final id = args["id"] as String;
        final chunk = args["chunk"] as Uint8List;
        final isComplete = args["isComplete"] as bool? ?? false;

        if (blueState.activeDevices.value().isEmpty) {
          return;
        }
        final device = getDevice(id);
        device.fileData.update(chunk);

        if (isComplete) {
          Logger.log("b", "File transfer complete for device $id");
        }

      case "summaryFileResponse":
        final args = call.arguments as Map;
        final id = args["id"] as String;
        final summaryData = args["data"] as Uint8List;

        if (blueState.activeDevices.value().isEmpty) {
          return;
        }
        final device = getDevice(id);
        device.summaryFile.update(summaryData);
        Logger.log("b", "Summary file received for device $id (${summaryData.length} bytes)");

      case "fileOperationComplete":
        final args = call.arguments as Map;
        final id = args["id"] as String;
        final operation = args["operation"] as String;
        final success = args["success"] as bool;

        if (blueState.activeDevices.value().isEmpty) {
          return;
        }
        final device = getDevice(id);
        final message = success ? "$operation completed successfully" : "$operation failed";
        device.message.update(message);
        Logger.log("b", "Device $id: $message");

      case "loggingStatusUpdate":
        final args = call.arguments as Map;
        final id = args["id"] as String;
        final isLogging = args["isLogging"] as bool;
        final dataTypes = args["dataTypes"] as int? ?? 0;

        if (blueState.activeDevices.value().isEmpty) {
          return;
        }
        final device = getDevice(id);
        if (isLogging) {
          device.loggingDataTypes.update(dataTypes);
          device.message.update("Logging started with data types: $dataTypes");
        } else {
          device.loggingDataTypes.update(0);
          device.message.update("Logging stopped");
        }
        Logger.log("b", "Device $id logging status: $isLogging");

        default:
          throw UnimplementedError("a method was called that does not exist: ${call.method}");
      }
    } catch (e) {
      Logger.log("b error", "Method handler error for ${call.method}: $e");
    }
  }

  void liveStreamPacketTimeout(LFLiner device) {
    try {
      checkMode(device.id);
    } catch (e) {
      Logger.log("b error", "Live stream packet timeout error for device ${device.name}: $e");
    }
  }
}
