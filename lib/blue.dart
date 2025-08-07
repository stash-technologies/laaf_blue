import 'dart:typed_data';

import 'package:blue/bluetooth_status.dart';

import 'blue_platform_interface.dart';
import 'device_state.dart';
import 'lf_liner.dart';

import 'logger.dart';

class Blue {
  // this always comes form the 'method channel''s copy of state,
  // meaning it is like a singleton (and the rest is functional, so has
  // no inherent state)
  final blueState = BluePlatform.instance.getBlueState();

  /// Returns 'true' if the platform executed the function.  The result of
  /// initialization will appear in 'blueState.bluetoothStatus' Observable
  /// (it will be 'available', or 'unavailable')
  Future<bool> initializeBluetooth() async {
    final bool? result = await BluePlatform.instance
        .initializeBluetooth()
        .timeout(const Duration(seconds: timeUntilTimeout),
            onTimeout:
                timeoutFunction("blue.initializeBluetooth", "bluetooth"));

    return nonNullResult(result);
  }

  Future<bool> Function() timeoutFunction(String label, String deviceId,
      {LFLiner? device}) {
    return () {
      Logger.log("timeout",
          "timeout occurred in function '$label' with device '$deviceId'");

      device?.remove();
      return Future<bool>(() => false);
    };
  }

  Future<bool> nonNullResult(bool? result) {
    if (result != null) {
      return Future<bool>(() => result);
    } else {
      return Future<bool>(() => false);
    }
  }

  static const int timeUntilTimeout = 3;

  /// Returns 'true' if the scan request was received by the platform.
  /// The devices found in the scan come back through the
  /// 'blueState.scannedDevices' Observable.
  Future<bool> scan(int duration) async {
    if (blueState.bluetoothStatus.value() == BluetoothStatus.available) {
      if (!blueState.scanning.value()) {
        final result = await BluePlatform.instance.scan(duration).timeout(
            Duration(seconds: timeUntilTimeout + duration),
            onTimeout: timeoutFunction("blue.scan", "bluetooth"));

        return nonNullResult(result);
      } else {
        return Future<bool>(() => false);
      }
    } else {
      return Future<bool>(() => false);
    }
  }

  /// returns 'true' if the stopScan request was received by the platform.
  Future<bool> stopScan() async {
    final result = await BluePlatform.instance.stopScan().timeout(
        const Duration(seconds: timeUntilTimeout),
        onTimeout: timeoutFunction("blue.stopScan", "bluetooth"));

    return nonNullResult(result);
  }

  // TODO => do all these booleans need to be adjusted to account for timeout?
  // [ true, false, or timeout]?
  // is it enough to log it now?

  /// Connect to the given LFLiner.  Returns 'false' if bluetooth is not available
  /// the platform times out, or the device is not in the platform's
  /// list of 'discoveredDevices'.  Connected devices (or those to which
  /// a connection attempt was made) appear in 'blueState.activeDevices'.
  /// Connection success will cause a change in the 'LFLiner.deviceState' Observable.
  ///
  ///
  /// NOTE: After a hot restart, some initial connection attempts seem to fail,
  /// and the device stays in an uninitialized state.  In these cases a second
  /// connection attempt (through the app itself (pressing 'connect' a second
  /// time in the case of the example app)) is successful.  I have only had it
  /// occur after a hot restart in vs code, which causes errors to appear in
  /// XCode about the validity of the bluetooth connection.  Which makes me
  /// think it is somehow related to how state persists across hot restarts
  /// (either way, it only appears in debugging).
  Future<bool> connect(LFLiner device) async {
    if (blueState.bluetoothStatus.value() == BluetoothStatus.available) {
      final devices = blueState.activeDevices.value();
      if (!devices.contains(device)) {
        devices.add(device);
        blueState.activeDevices.update(devices);
      }

      final result = await BluePlatform.instance.connect(device.id).timeout(
          const Duration(seconds: timeUntilTimeout),
          onTimeout: timeoutFunction(
              "blue.connect", device.id.substring(device.id.length - 5)));

      return nonNullResult(result);
    } else {
      return Future<bool>(() => false);
    }
  }

  /// Check whether or not the 'device' is currently logging.  The state of
  /// the 'device' will update in 'device.deviceState' Observable.
  ///
  /// NOTE: if the device is reset while streaming, it will wake up with the
  /// logging bit set to 1 (meaning the mode will indicate that it is logging)
  /// even though it isn't actually logging.
  Future<bool> checkMode(LFLiner device) async {
    if (blueState.bluetoothStatus.value() == BluetoothStatus.available) {
      final result = await BluePlatform.instance.checkMode(device.id).timeout(
          const Duration(seconds: timeUntilTimeout),
          onTimeout: timeoutFunction(
              "blue.checkMode", device.id.substring(device.id.length - 5)));

      Logger.log("check mode restul: $result");

      return nonNullResult(result);
    } else {
      return Future<bool>(() => false);
    }
  }

  /// Send a start log command to the 'device'. Returns 'false' if bluetooth
  /// is unavailable, the platform function times out, or the
  /// device does not receive the write command.
  Future<bool> startLog(LFLiner device) async {
    if (blueState.bluetoothStatus.value() == BluetoothStatus.available) {
      Uint8List startLog =
          Uint8List.fromList([0x01, 0x80, 0x00, 0x00, 0x00, 0x73]);
      final result = await BluePlatform.instance
          .sendCommand(device.id, startLog)
          .timeout(const Duration(seconds: timeUntilTimeout),
              onTimeout: timeoutFunction(
                  "blue.startLog", device.id.substring(device.id.length - 5)));

      return nonNullResult(result);
    } else {
      return Future<bool>(() => false);
    }
  }

  /// Sends a stop log command to the 'device'.  Returns 'false' if bluetooth
  /// is unavailable, the platform function exceeds the timeout,
  /// or the device does not receive the write command.
  Future<bool> stopLog(LFLiner device) async {
    if (blueState.bluetoothStatus.value() == BluetoothStatus.available) {
      Uint8List stopLog = Uint8List.fromList([0x02]);
      final result = await BluePlatform.instance
          .sendCommand(device.id, stopLog)
          .timeout(const Duration(seconds: timeUntilTimeout),
              onTimeout: timeoutFunction(
                  "blue.stopLog", device.id.substring(device.id.length - 5)));

      return nonNullResult(result);
    } else {
      return Future<bool>(() => false);
    }
  }


  // /// Sends a get summary file command to the 'device'.  Returns 'false' if bluetooth
  // /// is unavailable, the platform function exceeds the timeout,
  // /// or the device does not receive the write command.
  // Future<bool> getSummaryFile(LFLiner device) async {
  //   if (blueState.bluetoothStatus.value() == BluetoothStatus.available) {
  //     Uint8List getSummaryFile = Uint8List.fromList([0x10]);
  //     final result = await BluePlatform.instance
  //         .sendCommand(device.id, getSummaryFile)
  //         .timeout(const Duration(seconds: timeUntilTimeout),
  //             onTimeout: timeoutFunction(
  //                 "blue.getSummaryFile", device.id.substring(device.id.length - 5)));

  //     return nonNullResult(result);
  //   } else {
  //     return Future<bool>(() => false);
  //   }
  // }

  // /// Sends a get number of activity files command to the 'device'.  Returns 'false' if bluetooth
  // /// is unavailable, the platform function exceeds the timeout,
  // /// or the device does not receive the write command.
  // Future<bool> getNumberOfActivityFiles(LFLiner device) async {
  //   if (blueState.bluetoothStatus.value() == BluetoothStatus.available) {
  //     Uint8List getNumberOfActivityFiles = Uint8List.fromList([20]);
  //     final result = await BluePlatform.instance
  //         .sendCommand(device.id, getNumberOfActivityFiles)
  //         .timeout(const Duration(seconds: timeUntilTimeout),
  //             onTimeout: timeoutFunction(
  //                 "blue.getNumberOfActivityFiles", device.id.substring(device.id.length - 5)));

  //     return nonNullResult(result);
  //   } else {
  //     return Future<bool>(() => false);
  //   }
  // }


  // /// Sends a get file command to the 'device'.  Returns 'false' if bluetooth
  // /// is unavailable, the platform function exceeds the timeout,
  // /// or the device does not receive the write command.
  // Future<bool> getFile(LFLiner device) async {
  //   if (blueState.bluetoothStatus.value() == BluetoothStatus.available) {
  //     Uint8List getFile = Uint8List.fromList([0x21]);
  //     final result = await BluePlatform.instance
  //         .sendCommand(device.id, getFile)
  //         .timeout(const Duration(seconds: timeUntilTimeout),
  //             onTimeout: timeoutFunction(
  //                 "blue.getFile", device.id.substring(device.id.length - 5)));

  //     return nonNullResult(result);
  //   } else {
  //     return Future<bool>(() => false);
  //   }
  // }


  // /// Sends a erase file command to the 'device'.  Returns 'false' if bluetooth
  // /// is unavailable, the platform function exceeds the timeout,
  // /// or the device does not receive the write command.
  // Future<bool> eraseFile(LFLiner device) async {
  //   if (blueState.bluetoothStatus.value() == BluetoothStatus.available) {
  //     Uint8List eraseFile = Uint8List.fromList([0x22]);
  //     final result = await BluePlatform.instance
  //         .sendCommand(device.id, eraseFile)
  //         .timeout(const Duration(seconds: timeUntilTimeout),
  //             onTimeout: timeoutFunction(
  //                 "blue.eraseFile", device.id.substring(device.id.length - 5)));

  //     return nonNullResult(result);
  //   } else {
  //     return Future<bool>(() => false);
  //   }
  // }


  // /// Sends a erase all files command to the 'device'.  Returns 'false' if bluetooth
  // /// is unavailable, the platform function exceeds the timeout,
  // /// or the device does not receive the write command.
  // Future<bool> eraseAllFiles(LFLiner device) async {
  //   if (blueState.bluetoothStatus.value() == BluetoothStatus.available) {
  //     Uint8List eraseAllFiles = Uint8List.fromList([0x23]);
  //     final result = await BluePlatform.instance
  //         .sendCommand(device.id, eraseAllFiles)
  //         .timeout(const Duration(seconds: timeUntilTimeout),
  //             onTimeout: timeoutFunction(
  //                 "blue.eraseAllFiles", device.id.substring(device.id.length - 5)));

  //     return nonNullResult(result);
  //   } else {
  //     return Future<bool>(() => false);
  //   }
  // }

  

  /// Sends the start stream command to the 'device'.  Returns 'false' if
  /// bluetooth is unavailable, the platform function exceeds the
  /// timeout, or the device does not receive the write command.
  Future<bool> startStream(LFLiner device) async {
    if (blueState.bluetoothStatus.value() == BluetoothStatus.available) {
      Uint8List startStream = Uint8List.fromList([0x03, 0x01]);
      final result = await BluePlatform.instance
          .sendCommand(device.id, startStream)
          .timeout(const Duration(seconds: timeUntilTimeout),
              onTimeout: timeoutFunction("blue.startStream",
                  device.id.substring(device.id.length - 5)));

      return nonNullResult(result);
    } else {
      return Future<bool>(() => false);
    }
  }

  /// Send the stop stream command to the device.  Returns 'false' if
  /// bluetooth is unavailable, the platform function exceeds the timeout, or
  /// the device does not receive the write command.
  Future<bool> stopStream(LFLiner device) async {
    if (blueState.bluetoothStatus.value() == BluetoothStatus.available) {
      if (device.deviceState.value() == DeviceState.streaming) {
        Uint8List stopStream = Uint8List.fromList([0x04]);
        final result = await BluePlatform.instance
            .sendCommand(device.id, stopStream)
            .timeout(const Duration(seconds: timeUntilTimeout),
                onTimeout: timeoutFunction("blue.stopStream",
                    device.id.substring(device.id.length - 5)));

        if (result != null) {
          return result;
        }
      }

      return Future<bool>(() => false);
    } else {
      return Future<bool>(() => false);
    }
  }

  /// Sends the 'reset' command to the 'device'.  This takes a little time,
  /// because the device reset triggers a device disconnection. After resest,
  /// the device will still be in the 'blueState.activeDevices' list.  From there
  /// you can attempt a reconnection (through another 'device.connect' call), or
  /// you can remove it with 'device.remove'.
  Future<bool> reset(LFLiner device) async {
    if (blueState.bluetoothStatus.value() == BluetoothStatus.available) {
      final result = await BluePlatform.instance.reset(device.id);

      // TODO => get this to return a more descriptive value (timeout occurring)
      /*
    .timeout(
        const Duration(seconds: timeUntilTimeout + 5),
        onTimeout: timeoutFunction(
            "blue.reset", device.id.substring(device.id.length - 5)));
            */

      return nonNullResult(result);
    } else {
      return Future<bool>(() => false);
    }
  }

  /// Removes the 'device' from 'blueState.activeDevices' Observable.
  bool remove(LFLiner device) {
    Logger.log("b", "removing device $device.id");

    final devices = blueState.activeDevices.value();

    final preRemovalLength = devices.length;
    devices.removeWhere((d) => d.id == device.id);

    if (preRemovalLength == devices.length) {
      return false;
    }

    blueState.activeDevices.update(devices);

    return true;
  }

  /// Send the disconnect command to the 'device'.  This will also remove the device
  /// from the 'blueState.activeDevices' Observable (if the disconnection is
  /// successful).  Returns 'false' if bluetooth is unavailable, the platform
  /// function timesout, or there is a bluetooth problem on the platform side.
  Future<bool> disconnect(LFLiner device) async {
    if (blueState.bluetoothStatus.value() == BluetoothStatus.available) {
      final result = await BluePlatform.instance.disconnect(device.id).timeout(
          const Duration(seconds: timeUntilTimeout),
          onTimeout: timeoutFunction(
              "blue.disconnect", device.id.substring(device.id.length - 5),
              device: device));

      return nonNullResult(result);
    } else {
      return Future<bool>(() => false);
    }
  }
}
