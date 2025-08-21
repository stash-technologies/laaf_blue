import 'dart:async';
import 'dart:typed_data';

import 'package:blue/fsr_packet.dart';
import 'package:blue/step_data_packet.dart';
import 'package:blue/file_metadata.dart';
import 'package:blue/data_type_flags.dart';

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

  final Blue blue = Blue();

  /// The device's state [uninitialized, logging, idle, streaming, disconnected]
  Observable<DeviceState> deviceState = Observable(DeviceState.uninitialized);

  /// The last unparsed packet, received from the livestream characteristic
  Observable<Uint8List> liveStreamPacket = Observable(Uint8List.fromList([]));

  /// The last parsed fsr packet
  Observable<FSRPacket> fsrPacket = Observable(FSRPacket.empty());

  /// The last parsed step data packet
  Observable<StepDataPacket> stepPacket = Observable(StepDataPacket.empty());

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
  Future<bool> connect() {
    return blue.connect(this);
  } // TODO => make the return value more descriptive.

  /// Removes this device from the 'blueState.activeDevices' observable.
  /// Returns 'true' if the device was removed.  Use this when you want
  /// to stop keeping track of a disconnected device.
  bool remove() {
    if (deviceState.value() == DeviceState.disconnected) {
      return blue.remove(this);
    } else {
      // return blue.disconnect(this, keepAround = false);
      return false;
    }
  }

  /// Disconnect this device.  Returns 'true' if the disconnect was succesfully
  /// requested.  If the disconnection is succesful, the device will be removed
  /// from 'blueState.activeDevices'.
  Future<bool> disconnect() {
    return blue.disconnect(this);
  }

  /// Start logging.  Returns 'true' if the start log command was sent to the device.
  Future<bool> startLog() {
    return blue.startLog(this);
  }

  /// Stop logging.  Returns 'true' if the stop log command was sent to the device.
  Future<bool> stopLog() {
    return blue.stopLog(this);
  }

  // /// Get summary file.  Returns 'true' if the get summary file command was sent to the device.
  // Future<bool> getSummaryFile() {
  //   return blue.getSummaryFile(this);
  // }

  // /// Get number of activity files.  Returns 'true' if the get number of activity files command was sent to the device.
  // Future<bool> getNumberOfActivityFiles() {
  //   return blue.getNumberOfActivityFiles(this);
  // }

  // /// Get file.  Returns 'true' if the get file command was sent to the device.
  // Future<bool> getFile() {
  //   return blue.getFile(this);
  // }

  // /// Erase file.  Returns 'true' if the erase file command was sent to the device.
  // Future<bool> eraseFile() {
  //   return blue.eraseFile(this);
  // }

  // /// Erase all files.  Returns 'true' if the erase all files command was sent to the device.
  // Future<bool> eraseAllFiles() {
  //   return blue.eraseAllFiles(this);
  // }

  /// Start live streming step and fsr data from this device. All packet's will
  /// appear in their raw form in 'liveStreamPacket', or their parsed forms
  /// in the 'fsrPacket', or 'stepPacket' observables.  Returns 'true' if the
  /// start stream and start log commands were sent to the device.
  Future<bool> startLiveStream() async {
    final result = await blue.startStream(this);

    if (result == true) {
      return blue.startLogging(this, DataTypeFlags.all);
    } else {
      return result;
    }
  }

  /// Stop live streaming.  Returns 'true' if the stop log and stop stream commands
  /// were sent to the device.
  Future<bool> stopLiveStream() async {
    final result = await blue.stopLogging(this);

    if (result == true) {
      return blue.stopStream(this);
    } else {
      return result;
    }
  }

  /// This enables live streaming (though it does not start a live stream, that
  /// also requires the deviec to be logging).  Returns 'true' if the start stream
  /// command was sent to the device.
  Future<bool> startStream() {
    return blue.startStream(this);
  }

  /// Disable live streaming.  Returns 'true' if the stop stream command was
  /// sent to the device.
  Future<bool> stopStream() {
    return blue.stopStream(this);
  }

  /// Parses a raw packet, and updates the appropriate packet observable.
  void parseAndUpdatePacket(Uint8List rawPacket) {
    switch (rawPacket[0]) {
      case 0xD5:
        stepPacket.update(StepDataPacket(rawPacket));
        break;
      case 0xE0:
        fsrPacket.update(FSRPacket(rawPacket));
        break;
    }
  }

  /// Reset the device.  This returns 'true' if the command was sent
  /// and the 'deviceState' will change to 'disconnected' if it is successfully
  /// reset.  See the 'remove()' method for removing a device from the
  /// the 'blueState.activeDevices' observable.
  Future<bool> reset() {
    return blue.reset(this);
  }

  // New LAAF protocol file management methods

  /// Set the device time to synchronize with phone. Must be called before logging.
  Future<bool> setTime({DateTime? timestamp}) {
    return blue.setTime(this, timestamp: timestamp);
  }

  /// Start logging with specified data types. Use DataTypeFlags constants.
  /// Example: startLogging(DataTypeFlags.all) or startLogging(DataTypeFlags.stepData | DataTypeFlags.rawFSR)
  Future<bool> startLogging(int dataTypeFlags) async {
    loggingDataTypes.update(dataTypeFlags);
    return blue.startLogging(this, dataTypeFlags);
  }

  /// Stop logging. Must be called before retrieving files.
  Future<bool> stopLogging() async {
    final result = await blue.stopLogging(this);
    if (result) {
      loggingDataTypes.update(0);
    }
    return result;
  }

  /// Get the number of files stored on device. Updates fileCount observable.
  Future<bool> getNumberOfFiles() {
    return blue.getNumberOfFiles(this);
  }

  /// Retrieve a specific file by index (1-based). File data streams through fileData observable.
  Future<bool> getFile(int fileIndex) {
    return blue.getFile(this, fileIndex);
  }

  /// Erase a specific file by index (1-based). Note: This changes indices of remaining files.
  Future<bool> eraseFile(int fileIndex) {
    return blue.eraseFile(this, fileIndex);
  }

  /// Erase the last file. This is the only way to free memory space.
  Future<bool> eraseLastFile() {
    return blue.eraseLastFile(this);
  }

  /// Erase all files on device (format file system).
  Future<bool> eraseAllFiles() {
    return blue.eraseAllFiles(this);
  }

  /// Get summary file for quick access to device data. Data available in summaryFile observable.
  Future<bool> getSummaryFile() {
    return blue.getSummaryFile(this);
  }

  /// Convenience method: Set time and start logging with all data types
  Future<bool> startFullLogging({DateTime? timestamp}) async {
    final timeResult = await setTime(timestamp: timestamp);
    if (timeResult) {
      return startLogging(DataTypeFlags.all);
    }
    return false;
  }

  /// Convenience method: Stop logging and get file count
  Future<bool> stopLoggingAndGetFiles() async {
    final stopResult = await stopLogging();
    if (stopResult) {
      return getNumberOfFiles();
    }
    return false;
  }

  /// Removes observers from all observable values of the LFLiner that are
  /// associated with the given id.
  void removeAllRelevantObservers(int id) {
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
  }

  /// Remove all the observers associated with this LFLiner.  This can be a little
  /// dangerous, in the case that other parts of the app still want to be listening
  /// to these values.
  void removeAllObservers() {
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
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'side': side.toString(), // Assuming side is of type Foot enum
      // Include other properties as needed
    };
  }
}
