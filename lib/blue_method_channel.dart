import 'package:blue/step_data_packet.dart';
import 'package:flutter/services.dart';

import 'dart:async';

import 'blue_platform_interface.dart';

import 'blue_state.dart';
import 'lf_liner.dart';
import 'device_state.dart';
import 'bluetooth_status.dart';
import 'logger.dart';
import 'step.dart';

/// An implementation of [BluePlatform] that uses method channels.
class MethodChannelBlue extends BluePlatform {
  /// The method channel used to interact with the native platform.
  //@visibleForTesting
  final methodChannel = const MethodChannel('blue');

  final blueState = BlueState();

  MethodChannelBlue() {
    methodChannel.setMethodCallHandler(methodHandler);
  }

  @override
  BlueState getBlueState() {
    return blueState;
  }

  @override
  Future<bool?> initializeBluetooth() async {
    final uuids = [
      "00008801-0000-1000-8000-00805f9b34fb", // general service uuid
      "00008811-0000-1000-8000-00805f9b34fb", // command char uuid
      "00008812-0000-1000-8000-00805f9b34fb", // data char uuid
      "00008813-0000-1000-8000-00805f9b34fb", // mode char uuid
      "0000880E-0000-1000-8000-00805f9b34fb" // live stream data uuid
    ];
    final result =
        await methodChannel.invokeMethod<bool>('initializeBluetooth', uuids);

    return result;
  }

  @override
  Future<bool?> scan(int duration) async {
    final scanResult =
        await methodChannel.invokeMethod<bool?>('scan', duration);

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
  }

  @override
  Future<bool?> stopScan() async {
    if (!blueState.scanning.value()) {
      Logger.log("b warning",
          "a 'stopScan' was attempted when no scan was in progress");
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
  }

  @override
  Future<bool?> connect(String deviceId) async {
    Logger.log("b", "connecting to device $deviceId");

    final result = await methodChannel.invokeMethod<bool?>('connect', deviceId);

    return result;
  }

  @override
  Future<bool?> checkMode(String deviceId) async {
    Logger.log("b", "checking mode of device $deviceId");
    final result =
        await methodChannel.invokeMethod<bool?>('checkMode', deviceId);

    return result;
  }

  List<String> devicesStagedForDisconnection = [];

  @override
  @override
  Future<bool?> disconnect(String deviceId, {bool keepAround = true}) async {
    Logger.log("b", "disconnecting device $deviceId");

    if (keepAround && !devicesStagedForDisconnection.contains(deviceId)) {
      devicesStagedForDisconnection.add(deviceId);
    }

    final result =
        await methodChannel.invokeMethod<bool?>('disconnect', deviceId);

    return result;
  }

  @override
  Future<bool?> reset(String deviceId) async {
    Logger.log("b", "resetting: $deviceId");
    final args = {
      "device": deviceId,
      "command": Uint8List.fromList([0x51])
    };
    final result = await methodChannel.invokeMethod<bool?>('sendCommand', args);

    return result;
  }

  @override
  Future<bool?> sendCommand(String deviceId, Uint8List command) async {
    Logger.log("b", "sending command $command to $deviceId");

    final args = {"device": deviceId, "command": command};
    final result = await methodChannel.invokeMethod<bool?>('sendCommand', args);

    return result;
  }

  LFLiner getDevice(String id) {
    return blueState.activeDevices.value().firstWhere((l) => l.id == id);
  }

  Future<void> methodHandler(MethodCall call) async {
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
          LFLiner device = getDevice(id);

          device.message.update(message);
          Logger.log("b", message);
        } else {
          blueState.blueMessage.update(message);
        }

      case "updateDetectedDevices":
        List<LFLiner> newDevices = (call.arguments as List)
            .map((o) => LFLiner.deviceFromMap(o))
            .toList();
        blueState.scannedDevices.update(newDevices);

      case "connectionComplete":
        final id = call.arguments as String;

        // reset step calculator

        blueState.stepDataClaculator.reset();

        checkMode(id);

      case "updateDeviceState":
        final args = call.arguments as Map;
        final id = args["id"] as String;
        final DeviceState updatedState =
            DeviceState.values[args["state"] as int];
        Logger.log("b", "device state update: $id / $updatedState");

        final device = getDevice(id);

        // clear messages
        device.message.update("state updated...");

        device.deviceState.update(updatedState);

        if (updatedState == DeviceState.logging) {
          /// the device thinks it logging if it reset when streaming...
        }

      case "deviceDisconnected":
        final id = call.arguments as String;

        final device = getDevice(id);

        device.deviceState.update(DeviceState.disconnected);

        if (devicesStagedForDisconnection.contains(id)) {
          print("removing device from active devices");
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

        final device = getDevice(id);

        if (device.liveStreamPacket.hasObservers()) {
          device.liveStreamPacket.update(packet);
        }

        if (packet[0] == 0xD5) {
          final data = StepDataPacket(packet);
          blueState.stepDataClaculator.addStep(Step(data.timestamp.toInt(),
              data.timestamp.toInt() + data.contactTime.toInt(), device.side));
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

      default:
        throw UnimplementedError(
            "a method was called that does not exist: ${call.method}");
    }
  }

  void liveStreamPacketTimeout(LFLiner device) {
    checkMode(device.id);
  }
}
