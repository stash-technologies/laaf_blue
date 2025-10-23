import 'dart:async';
import 'dart:typed_data';

import 'package:blue/data_type_flags.dart';
import 'package:blue/file_metadata.dart';
import 'package:blue/fsr_packet.dart';
import 'package:blue/imu_packet.dart';
import 'package:blue/logger.dart';
import 'package:blue/step_data_packet.dart';

import 'blue.dart';
import 'device_state.dart';
import 'foot.dart';
import 'observable.dart';

/// Class for communication with a LAAF sock liner.
class LFLiner {
  // This is the 'mac' on android, and generated 'cbuuid' on ios
  final String id;
  final String name;
  Foot side = Foot.left;
  String firmwareVersion = "";

  final Blue blue = Blue();

  /// The device's state [uninitialized, logging, idle, streaming, disconnected]
  Observable<DeviceState> deviceState = Observable(DeviceState.uninitialized);

  /// The last unparsed packet, received from the livestream characteristic
  Observable<Uint8List> liveStreamPacket = Observable(Uint8List.fromList([]));

  /// The last parsed fsr packet
  Observable<FSRPacket> fsrPacket = Observable(FSRPacket.empty());

  /// The last parsed step data packet
  Observable<StepDataPacket> stepPacket = Observable(StepDataPacket.empty());

  /// The last parsed IMU packet
  Observable<IMUPacket> imuPacket = Observable(IMUPacket.empty());

  /// Messages received from other parts of the library that are
  /// relevant to this particular device (mostly for bluetooth logging /
  /// debugging)
  Observable<String> message = Observable("");

  /// Number of files stored on the device
  Observable<int> fileCount = Observable(0);

  /// List of file metadata for files stored on device
  Observable<List<FileMetadata>> fileList = Observable([]);

  /// Currently downloading/active file data
  Observable<FileMetadata> activeFile = Observable(FileMetadata.empty());

  /// Raw file data being received from device
  Observable<Uint8List> fileData = Observable(Uint8List.fromList([]));

  /// Summary file data from device
  Observable<Uint8List> summaryFile = Observable(Uint8List.fromList([]));

  /// Current logging data type flags
  Observable<int> loggingDataTypes = Observable(0);

  LFLiner(this.id, this.name) {
    deviceState.name = "d_state ($id)";
    liveStreamPacket.name = "packet ($id)";
    message.name = "msg ($id)";
    fileCount.name = "file_count ($id)";
    fileList.name = "file_list ($id)";
    activeFile.name = "active_file ($id)";
    fileData.name = "file_data ($id)";
    summaryFile.name = "summary_file ($id)";
    loggingDataTypes.name = "logging_types ($id)";
    imuPacket.name = "imu_packet ($id)";

    bool isRight = name.contains('R');
    if (isRight) {
      side = Foot.right;
    }
  }

  /// Values used to determine whether or not the device is still streaming
  Timer? timer;
  int lastPacketTime = 0;

  static LFLiner deviceFromMap(Map map) {
    return LFLiner(map["id"], map["name"]);
  }

  /// Returns an empty LFLiner.
  static LFLiner emptyDevice() {
    return LFLiner("empty", "0000-empty");
  }

  isEmpty() {
    return id == emptyDevice().id;
  }

  @override
  toString() {
    return "LFLiner {$name / ...${id.substring(id.length - 5)}";
  }

  /// Connect to this device.  Returns 'true' if the connection command was sent to the device.
  /// If the connection attempt is succesful, then this LFLiner's 'deviceState'
  /// value will be updated (to 'idle', 'logging', or 'streaming').
  Future<bool> connect() async {
    try {
      return await blue.connect(this);
    } catch (e) {
      message.update('Connection error: $e');
      return false;
    }
  }

  /// Removes this device from the 'blueState.activeDevices' observable.
  /// Returns 'true' if the device was removed.  Use this when you want
  /// to stop keeping track of a disconnected device.
  bool remove() {
    try {
      if (deviceState.value() == DeviceState.disconnected) {
        return blue.remove(this);
      } else {
        // return blue.disconnect(this, keepAround = false);
        return false;
      }
    } catch (e) {
      message.update('Remove error: $e');
      return false;
    }
  }

  /// Disconnect this device.  Returns 'true' if the disconnect was succesfully
  /// requested.  If the disconnection is succesful, the device will be removed
  /// from 'blueState.activeDevices'.
  Future<bool> disconnect() async {
    try {
      return await blue.disconnect(this);
    } catch (e) {
      message.update('Disconnect error: $e');
      return false;
    }
  }

  /// Start logging.  Returns 'true' if the start log command was sent to the device.
  Future<bool> startLog() async {
    try {
      return await blue.startLog(this);
    } catch (e) {
      message.update('Start log error: $e');
      return false;
    }
  }

  /// Stop logging.  Returns 'true' if the stop log command was sent to the device.
  Future<bool> stopLog() async {
    try {
      return await blue.stopLog(this);
    } catch (e) {
      message.update('Stop log error: $e');
      return false;
    }
  }

  /// Start live streming step and fsr data from this device. All packet's will
  /// appear in their raw form in 'liveStreamPacket', or their parsed forms
  /// in the 'fsrPacket', or 'stepPacket' observables.  Returns 'true' if the
  /// start stream and start log commands were sent to the device.
  Future<bool> startLiveStream() async {
    try {
      final result = await blue.startStream(this);

      if (result == true) {
        return await blue.startLogging(this, DataTypeFlags.all);
      } else {
        return result;
      }
    } catch (e) {
      message.update('Start live stream error: $e');
      return false;
    }
  }

  /// Stop live streaming.  Returns 'true' if the stop log and stop stream commands
  /// were sent to the device.
  Future<bool> stopLiveStream() async {
    try {
      final result = await blue.stopLogging(this);

      if (result == true) {
        return await blue.stopStream(this);
      } else {
        return result;
      }
    } catch (e) {
      message.update('Stop live stream error: $e');
      return false;
    }
  }

  /// This enables live streaming (though it does not start a live stream, that
  /// also requires the deviec to be logging).  Returns 'true' if the start stream
  /// command was sent to the device.
  Future<bool> startStream() async {
    try {
      return await blue.startStream(this);
    } catch (e) {
      message.update('Start stream error: $e');
      return false;
    }
  }

  /// Disable live streaming.  Returns 'true' if the stop stream command was
  /// sent to the device.
  Future<bool> stopStream() async {
    try {
      return await blue.stopStream(this);
    } catch (e) {
      message.update('Stop stream error: $e');
      return false;
    }
  }

  /// Parses a raw packet, and updates the appropriate packet observable.
  /// Used for live streaming data only.
  void parseAndUpdatePacket(Uint8List rawPacket) {
    if (rawPacket.isEmpty) return;
    try {
      switch (rawPacket[0]) {
        case 0xD5:
          Logger.log('LIVE_STREAM DEBUG', 'Using StepDataPacket for parsing');
          stepPacket.update(StepDataPacket(rawPacket));
          break;
        case 0xE0:
          fsrPacket.update(FSRPacket(rawPacket));
          break;
        case 0xD0:
          Logger.log('LIVE_STREAM DEBUG', 'Using IMUPacket for parsing');
          imuPacket.update(IMUPacket(rawPacket));
          break;
      }
    } catch (e) {
      message.update('Parse packet error: $e');
    }
  }

  /// Parses file data containing multiple packets and returns parsed packets.
  /// File data format: raw packets concatenated together with Unix timestamps.
  List<Map<String, dynamic>> parseFileData(Uint8List fileData) {
    try {
      List<Map<String, dynamic>> parsedPackets = [];
      int offset = 0;

      Logger.log('LF_LINER DEBUG', 'File data length: ${fileData.length}');
      Logger.log('LF_LINER DEBUG', 'First 20 bytes: ${fileData.take(20).toList()}');

      while (offset < fileData.length) {
        if (offset >= fileData.length) break;

        int packetId = fileData[offset];
        Logger.log('LF_LINER DEBUG',
            'Offset $offset: Found packet ID 0x${packetId.toRadixString(16).padLeft(2, '0')} ($packetId)');

        Map<String, dynamic>? packet;

        switch (packetId) {
          case 0xD5: // 213
            if (offset + 24 <= fileData.length) {
              Logger.log('LF_LINER DEBUG', 'Parsing step data packet at offset $offset');
              packet = parseRawStepDataPacket(fileData.sublist(offset, offset + 24));
              offset += 24;
            } else {
              Logger.log('LF_LINER DEBUG', 'Incomplete step data packet at offset $offset');
              offset = fileData.length;
            }
            break;
          case 0xE0: // 224
            if (offset + 21 <= fileData.length) {
              Logger.log('LF_LINER DEBUG', 'Parsing FSR data packet at offset $offset');
              packet = parseRawFSRDataPacket(fileData.sublist(offset, offset + 21));
              offset += 21;
            } else {
              Logger.log('LF_LINER DEBUG', 'Incomplete FSR data packet at offset $offset');
              offset = fileData.length;
            }
            break;
          case 0xD0: // 208 - Raw IMU
            if (offset + 19 <= fileData.length) {
              Logger.log('LF_LINER DEBUG', 'Parsing IMU data packet at offset $offset');
              packet = parseRawIMUDataPacket(fileData.sublist(offset, offset + 19));
              offset += 19;
            } else {
              Logger.log('LF_LINER DEBUG', 'Incomplete IMU data packet at offset $offset');
              offset = fileData.length;
            }
            break;
          default:
            Logger.log(
                'LF_LINER DEBUG', 'Unknown packet ID 0x${packetId.toRadixString(16)} at offset $offset, skipping');
            offset++;
            break;
        }

        if (packet != null) {
          parsedPackets.add(packet);
          Logger.log('LF_LINER DEBUG', 'Successfully parsed packet: ${packet['packetType']}');
        }
      }

      Logger.log('LF_LINER DEBUG', 'Total packets parsed: ${parsedPackets.length}');
      return parsedPackets;
    } catch (e) {
      message.update('Parse file data error: $e');
      return [];
    }
  }

  /// Parses raw step data packet from file (24 bytes, same format as live streaming)
  Map<String, dynamic> parseRawStepDataPacket(Uint8List packet) {
    try {
      if (packet.length != 24 || packet[0] != 0xD5) {
        throw ArgumentError('Invalid step data packet');
      }

      // Parse using little-endian format
      final data = ByteData.sublistView(packet);

      return {
        'packetType': 'stepData',
        'packetId': packet[0],
        'timestamp': data.getUint32(1, Endian.little), // milliseconds from start
        'heelStrikeAngle': data.getInt16(5, Endian.little) / 100.0, // degrees
        'pronationAngle': data.getInt16(7, Endian.little) / 100.0, // degrees
        'cadence': packet[9], // steps/min
        'speed': data.getUint16(10, Endian.little) / 1000.0, // m/s
        'strideTime': data.getUint16(12, Endian.little), // ms/step
        'strideLength': packet[14] / 100.0, // m/step
        'contactTime': data.getUint16(15, Endian.little), // ms
        'swingTime': data.getUint16(17, Endian.little), // ms
        'stepClearance': packet[19], // mm
        'totalSteps': data.getUint16(20, Endian.little), // steps
        'totalDistance': data.getUint16(22, Endian.little), // m
      };
    } catch (e) {
      message.update('Parse step data packet error: $e');
      return {'packetType': 'stepData', 'error': e.toString()};
    }
  }

  /// Parses raw FSR data packet from file (21 bytes with Unix timestamp)
  Map<String, dynamic> parseRawFSRDataPacket(Uint8List packet) {
    try {
      if (packet.length != 21 || packet[0] != 0xE0) {
        throw ArgumentError('Invalid FSR data packet');
      }

      // Parse using little-endian format
      final data = ByteData.sublistView(packet);

      return {
        'packetType': 'fsrData',
        'packetId': packet[0],
        'timestampSeconds': data.getUint32(1, Endian.little), // Unix timestamp seconds
        'timestampMilliseconds': data.getUint16(5, Endian.little), // milliseconds
        'fsr1': data.getUint16(7, Endian.little), // A/D units
        'fsr2': data.getUint16(9, Endian.little), // A/D units
        'fsr3': data.getUint16(11, Endian.little), // A/D units
        'fsr4': data.getUint16(13, Endian.little), // A/D units
        'fsr5': data.getUint16(15, Endian.little), // A/D units
        'fsr6': data.getUint16(17, Endian.little), // A/D units
        'fsr7': data.getUint16(19, Endian.little), // A/D units
      };
    } catch (e) {
      message.update('Parse FSR data packet error: $e');
      return {'packetType': 'fsrData', 'error': e.toString()};
    }
  }

  /// Parses raw IMU data packet from file (19 bytes with Unix timestamp)
  Map<String, dynamic> parseRawIMUDataPacket(Uint8List packet) {
    try {
      if (packet.length != 19 || packet[0] != 0xD0) {
        throw ArgumentError('Invalid IMU data packet');
      }

      // Parse using little-endian format
      final data = ByteData.sublistView(packet);

      // Scale factor: 16,384 AD/g @ 2g
      const double scaleFactor = 16384.0;

      return {
        'packetType': 'imuData',
        'packetId': packet[0],
        'timestampSeconds': data.getUint32(1, Endian.little), // Unix timestamp seconds
        'timestampMilliseconds': data.getUint16(5, Endian.little), // milliseconds
        'accX': data.getInt16(7, Endian.little) / scaleFactor, // g units
        'accY': data.getInt16(9, Endian.little) / scaleFactor, // g units
        'accZ': data.getInt16(11, Endian.little) / scaleFactor, // g units
        'gyroX': data.getInt16(13, Endian.little) / scaleFactor, // deg/s (using same scale per docs)
        'gyroY': data.getInt16(15, Endian.little) / scaleFactor, // deg/s
        'gyroZ': data.getInt16(17, Endian.little) / scaleFactor, // deg/s
      };
    } catch (e) {
      message.update('Parse IMU data packet error: $e');
      return {'packetType': 'imuData', 'error': e.toString()};
    }
  }

  /// Reset the device.  This returns 'true' if the command was sent
  /// and the 'deviceState' will change to 'disconnected' if it is successfully
  /// reset.  See the 'remove()' method for removing a device from the
  /// the 'blueState.activeDevices' observable.
  Future<bool> reset() async {
    try {
      return await blue.reset(this);
    } catch (e) {
      message.update('Reset error: $e');
      return false;
    }
  }

  /// Enter DFU mode. Sends 0x52 command to put the device into Device Firmware Update mode.
  /// The device will disconnect after entering DFU mode and will be available for firmware updates.
  Future<bool> enterDFUMode() async {
    try {
      return await blue.enterDFUMode(this);
    } catch (e) {
      message.update('Enter DFU mode error: $e');
      return false;
    }
  }

  /// Get the MAC address (or unique identifier) for this device.
  /// On iOS, this returns the device's UUID identifier due to privacy restrictions.
  /// On Android, this may return the actual MAC address.
  /// The device must be connected for this to work.
  Future<String?> getMacAddress() async {
    try {
      return await blue.getMacAddress(this);
    } catch (e) {
      message.update('Get MAC address error: $e');
      return null;
    }
  }

  /// Get the firmware version from the Device Information Service.
  /// Reads the Firmware Revision String characteristic (UUID: 0x2A26).
  /// The device must be connected for this to work.
  /// Updates the firmwareVersion property with the result.
  Future<String?> getFirmwareVersion() async {
    try {
      final version = await blue.getFirmwareVersion(this);
      if (version != null) {
        firmwareVersion = version;
      }
      return version;
    } catch (e) {
      message.update('Get firmware version error: $e');
      return null;
    }
  }

  // New LAAF protocol file management methods

  /// Set the device time to synchronize with phone. Must be called before logging.
  Future<bool> setTime({DateTime? timestamp}) async {
    try {
      return await blue.setTime(this, timestamp: timestamp);
    } catch (e) {
      message.update('Set time error: $e');
      return false;
    }
  }

  /// Start logging with specified data types. Use DataTypeFlags constants.
  /// Example: startLogging(DataTypeFlags.all) or startLogging(DataTypeFlags.stepData | DataTypeFlags.rawFSR)
  Future<bool> startLogging(int dataTypeFlags) async {
    try {
      loggingDataTypes.update(dataTypeFlags);
      return await blue.startLogging(this, dataTypeFlags);
    } catch (e) {
      message.update('Start logging error: $e');
      return false;
    }
  }

  /// Stop logging. Must be called before retrieving files.
  Future<bool> stopLogging() async {
    try {
      final result = await blue.stopLogging(this);
      if (result) {
        loggingDataTypes.update(0);
      }
      return result;
    } catch (e) {
      message.update('Stop logging error: $e');
      return false;
    }
  }

  /// Get the number of files stored on device. Updates fileCount observable.
  Future<bool> getNumberOfFiles() async {
    try {
      return await blue.getNumberOfFiles(this);
    } catch (e) {
      message.update('Get number of files error: $e');
      return false;
    }
  }

  /// Retrieve a specific file by index (1-based). File data streams through fileData observable.
  Future<bool> getFile(int fileIndex) async {
    try {
      return await blue.getFile(this, fileIndex);
    } catch (e) {
      message.update('Get file error: $e');
      return false;
    }
  }

  /// Erase a specific file by index (1-based). Note: This changes indices of remaining files.
  Future<bool> eraseFile(int fileIndex) async {
    try {
      return await blue.eraseFile(this, fileIndex);
    } catch (e) {
      message.update('Erase file error: $e');
      return false;
    }
  }

  /// Erase the last file. This is the only way to free memory space.
  Future<bool> eraseLastFile() async {
    try {
      return await blue.eraseLastFile(this);
    } catch (e) {
      message.update('Erase last file error: $e');
      return false;
    }
  }

  /// Erase all files on device (format file system).
  Future<bool> eraseAllFiles() async {
    try {
      return await blue.eraseAllFiles(this);
    } catch (e) {
      message.update('Erase all files error: $e');
      return false;
    }
  }

  /// Get summary file for quick access to device data. Data available in summaryFile observable.
  Future<bool> getSummaryFile() async {
    try {
      return await blue.getSummaryFile(this);
    } catch (e) {
      message.update('Get summary file error: $e');
      return false;
    }
  }

  /// Convenience method: Set time and start logging with all data types
  Future<bool> startFullLogging({DateTime? timestamp}) async {
    try {
      final timeResult = await setTime(timestamp: timestamp);
      if (timeResult) {
        return await startLogging(DataTypeFlags.all);
      }
      return false;
    } catch (e) {
      message.update('Start full logging error: $e');
      return false;
    }
  }

  /// Convenience method: Stop logging and get file count
  Future<bool> stopLoggingAndGetFiles() async {
    try {
      final stopResult = await stopLogging();
      if (stopResult) {
        return await getNumberOfFiles();
      }
      return false;
    } catch (e) {
      message.update('Stop logging and get files error: $e');
      return false;
    }
  }

  /// Removes observers from all observable values of the LFLiner that are
  /// associated with the given id.
  void removeAllRelevantObservers(int id) {
    try {
      deviceState.removeRelevantObservers(id);
      message.removeRelevantObservers(id);
      fsrPacket.removeRelevantObservers(id);
      stepPacket.removeRelevantObservers(id);
      liveStreamPacket.removeRelevantObservers(id);
      // File management observables
      fileCount.removeRelevantObservers(id);
      fileList.removeRelevantObservers(id);
      activeFile.removeRelevantObservers(id);
      fileData.removeRelevantObservers(id);
      summaryFile.removeRelevantObservers(id);
      loggingDataTypes.removeRelevantObservers(id);
    } catch (e) {
      message.update('Remove relevant observers error: $e');
    }
  }

  /// Remove all the observers associated with this LFLiner.  This can be a little
  /// dangerous, in the case that other parts of the app still want to be listening
  /// to these values.
  void removeAllObservers() {
    try {
      deviceState.removeAllObservers();
      message.removeAllObservers();
      liveStreamPacket.removeAllObservers();
      fsrPacket.removeAllObservers();
      stepPacket.removeAllObservers();
      // File management observables
      fileCount.removeAllObservers();
      fileList.removeAllObservers();
      activeFile.removeAllObservers();
      fileData.removeAllObservers();
      summaryFile.removeAllObservers();
      loggingDataTypes.removeAllObservers();
    } catch (e) {
      message.update('Remove all observers error: $e');
    }
  }

  Map<String, dynamic> toJson() {
    try {
      return {
        'id': id,
        'name': name,
        'side': side.toString(), // Assuming side is of type Foot enum
        // Include other properties as needed
      };
    } catch (e) {
      message.update('toJson error: $e');
      return {'error': e.toString()};
    }
  }
}
