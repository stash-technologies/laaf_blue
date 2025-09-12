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
  /// Set [onlyDfuDevices] to true to scan only for DFU target devices.
  Future<bool> scan(int duration, {bool onlyDfuDevices = false}) async {
    if (blueState.bluetoothStatus.value() == BluetoothStatus.available) {
      if (!blueState.scanning.value()) {
        final result = await BluePlatform.instance.scan(duration, onlyDfuDevices: onlyDfuDevices).timeout(
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

  /// Sends the DFU mode command (0x52) to the device. This will put the device
  /// into Device Firmware Update mode for firmware updates. The device will
  /// disconnect after entering DFU mode.
  Future<bool> enterDFUMode(LFLiner device) async {
    if (blueState.bluetoothStatus.value() == BluetoothStatus.available) {
      final result = await BluePlatform.instance.enterDFUMode(device.id);
      return nonNullResult(result);
    } else {
      return Future<bool>(() => false);
    }
  }

  /// Convenience method to scan for DFU devices only.
  /// This will scan for devices advertising the DFU target service UUID (0000fe59).
  Future<bool> scanForDFUDevices(int duration) async {
    return scan(duration, onlyDfuDevices: true);
  }

  /// Get the MAC address (or unique identifier) for a connected device.
  /// On iOS, this returns the device's UUID identifier due to privacy restrictions.
  /// On Android, this may return the actual MAC address.
  Future<String?> getMacAddress(LFLiner device) async {
    if (blueState.bluetoothStatus.value() == BluetoothStatus.available) {
      final result = await BluePlatform.instance.getMacAddress(device.id);
      return result;
    } else {
      return null;
    }
  }

  /// Get the firmware version from the Device Information Service.
  /// Reads the Firmware Revision String characteristic (UUID: 0x2A26).
  /// The device must be connected for this to work.
  Future<String?> getFirmwareVersion(LFLiner device) async {
    if (blueState.bluetoothStatus.value() == BluetoothStatus.available) {
      final result = await BluePlatform.instance.getFirmwareVersion(device.id);
      return result;
    } else {
      return null;
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

  // New LAAF protocol methods for file management and enhanced logging

  /// Set the device time to synchronize with the phone before logging.
  /// This should be called before starting any logging session.
  Future<bool> setTime(LFLiner device, {DateTime? timestamp}) async {
    if (blueState.bluetoothStatus.value() == BluetoothStatus.available) {
      final timeToSet = timestamp ?? DateTime.now();
      final result = await BluePlatform.instance.setTime(device.id, timeToSet)
          .timeout(const Duration(seconds: timeUntilTimeout),
              onTimeout: timeoutFunction("blue.setTime",
                  device.id.substring(device.id.length - 5)));

      return nonNullResult(result);
    } else {
      return Future<bool>(() => false);
    }
  }

  /// Start logging with specified data types. Must call setTime() first.
  /// dataTypeFlags can be combined: DataTypeFlags.stepData | DataTypeFlags.rawIMU
  Future<bool> startLogging(LFLiner device, int dataTypeFlags) async {
    if (blueState.bluetoothStatus.value() == BluetoothStatus.available) {
      final result = await BluePlatform.instance.startLogging(device.id, dataTypeFlags)
          .timeout(const Duration(seconds: timeUntilTimeout),
              onTimeout: timeoutFunction("blue.startLogging",
                  device.id.substring(device.id.length - 5)));

      return nonNullResult(result);
    } else {
      return Future<bool>(() => false);
    }
  }

  /// Stop logging. Must be called before retrieving files from device.
  Future<bool> stopLogging(LFLiner device) async {
    if (blueState.bluetoothStatus.value() == BluetoothStatus.available) {
      final result = await BluePlatform.instance.stopLogging(device.id)
          .timeout(const Duration(seconds: timeUntilTimeout),
              onTimeout: timeoutFunction("blue.stopLogging",
                  device.id.substring(device.id.length - 5)));

      return nonNullResult(result);
    } else {
      return Future<bool>(() => false);
    }
  }

  /// Get the number of files stored on the device.
  /// The actual count will be updated in the device's fileCount observable.
  Future<bool> getNumberOfFiles(LFLiner device) async {
    if (blueState.bluetoothStatus.value() == BluetoothStatus.available) {
      final result = await BluePlatform.instance.getNumberOfFiles(device.id)
          .timeout(const Duration(seconds: timeUntilTimeout),
              onTimeout: () {
                Logger.log("timeout", "timeout occurred in function 'blue.getNumberOfFiles' with device '${device.id.substring(device.id.length - 5)}'");
                device.remove();
                return Future<int?>(() => null);
              });

      return result != null;
    } else {
      return Future<bool>(() => false);
    }
  }

  /// Retrieve a specific file by index (1-based indexing).
  /// File data will be streamed through the device's fileData observable.
  Future<bool> getFile(LFLiner device, int fileIndex) async {
    if (blueState.bluetoothStatus.value() == BluetoothStatus.available) {
      if (fileIndex < 1) {
        Logger.log("blue.getFile", "File index must be >= 1 (1-based indexing)");
        return Future<bool>(() => false);
      }

      final result = await BluePlatform.instance.getFile(device.id, fileIndex)
          .timeout(const Duration(seconds: timeUntilTimeout),
              onTimeout: timeoutFunction("blue.getFile",
                  device.id.substring(device.id.length - 5)));

      return nonNullResult(result);
    } else {
      return Future<bool>(() => false);
    }
  }

  /// Erase a specific file by index (1-based indexing).
  /// Note: Erasing files changes the indices of remaining files.
  Future<bool> eraseFile(LFLiner device, int fileIndex) async {
    if (blueState.bluetoothStatus.value() == BluetoothStatus.available) {
      if (fileIndex < 1) {
        Logger.log("blue.eraseFile", "File index must be >= 1 (1-based indexing)");
        return Future<bool>(() => false);
      }

      final result = await BluePlatform.instance.eraseFile(device.id, fileIndex)
          .timeout(const Duration(seconds: timeUntilTimeout),
              onTimeout: timeoutFunction("blue.eraseFile",
                  device.id.substring(device.id.length - 5)));

      return nonNullResult(result);
    } else {
      return Future<bool>(() => false);
    }
  }

  /// Erase the last file. This is the only way to free up memory space.
  /// Can be called repeatedly to erase files from newest to oldest.
  Future<bool> eraseLastFile(LFLiner device) async {
    if (blueState.bluetoothStatus.value() == BluetoothStatus.available) {
      final result = await BluePlatform.instance.eraseLastFile(device.id)
          .timeout(const Duration(seconds: timeUntilTimeout),
              onTimeout: timeoutFunction("blue.eraseLastFile",
                  device.id.substring(device.id.length - 5)));

      return nonNullResult(result);
    } else {
      return Future<bool>(() => false);
    }
  }

  /// Erase all files on the device (format file system).
  Future<bool> eraseAllFiles(LFLiner device) async {
    if (blueState.bluetoothStatus.value() == BluetoothStatus.available) {
      final result = await BluePlatform.instance.eraseAllFiles(device.id)
          .timeout(const Duration(seconds: timeUntilTimeout),
              onTimeout: timeoutFunction("blue.eraseAllFiles",
                  device.id.substring(device.id.length - 5)));

      return nonNullResult(result);
    } else {
      return Future<bool>(() => false);
    }
  }

  /// Get the summary file for quick access to device data.
  /// Summary data will be available through the device's summaryFile observable.
  Future<bool> getSummaryFile(LFLiner device) async {
    if (blueState.bluetoothStatus.value() == BluetoothStatus.available) {
      final result = await BluePlatform.instance.getSummaryFile(device.id)
          .timeout(const Duration(seconds: timeUntilTimeout),
              onTimeout: timeoutFunction("blue.getSummaryFile",
                  device.id.substring(device.id.length - 5)));

      return nonNullResult(result);
    } else {
      return Future<bool>(() => false);
    }
  }
}
