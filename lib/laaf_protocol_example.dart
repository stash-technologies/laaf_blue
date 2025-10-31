import 'package:blue/blue.dart';
import 'package:blue/data_type_flags.dart';
import 'package:blue/lf_liner.dart';

/// Example usage of the new LAAF protocol file management features
class LaafProtocolExample {
  final Blue blue = Blue();

  /// Example 1: Basic logging workflow
  Future<void> basicLoggingWorkflow(LFLiner device) async {
    print('Starting basic logging workflow...');

    // Step 1: Set device time (required before logging)
    bool timeSet = await device.setTime();
    if (!timeSet) {
      print('Failed to set device time');
      return;
    }
    print('Device time synchronized');

    // Step 2: Start logging with all data types
    bool loggingStarted = await device.startLogging(DataTypeFlags.all);
    if (!loggingStarted) {
      print('Failed to start logging');
      return;
    }
    print('Logging started with all data types');

    // Simulate some logging time
    await Future.delayed(const Duration(seconds: 10));

    // Step 3: Stop logging
    bool loggingStopped = await device.stopLogging();
    if (!loggingStopped) {
      print('Failed to stop logging');
      return;
    }
    print('Logging stopped');

    // Step 4: Get number of files
    bool filesRequested = await device.getNumberOfFiles();
    if (filesRequested) {
      print('File count requested - check device.fileCount observable');
    }
  }

  /// Example 2: File management workflow
  Future<void> fileManagementWorkflow(LFLiner device) async {
    print('Starting file management workflow...');

    // Get file count
    await device.getNumberOfFiles();

    // Observe file count changes
    device.fileCount.observeChanges(1, (count) {
      print('Device has $count files');

      if (count > 0) {
        // Download the first file
        device.getFile(1);
      }
    });

    // Observe file data
    device.fileData.observeChanges(2, (data) {
      // print('Received file data chunk: ${data.length} bytes');
      // Process file data here
    });

    // Get summary file for quick overview
    await device.getSummaryFile();

    device.summaryFile.observeChanges(3, (summaryData) {
      // print('Received summary file: ${summaryData.length} bytes');
      // Process summary data here
    });
  }

  /// Example 3: Selective data type logging
  Future<void> selectiveLoggingWorkflow(LFLiner device) async {
    print('Starting selective logging workflow...');

    // Set time first
    await device.setTime();

    // Log only step data and FSR data (no IMU)
    int dataTypes = DataTypeFlags.stepData | DataTypeFlags.rawFSR;
    bool started = await device.startLogging(dataTypes);

    if (started) {
      print('Started logging step and FSR data only');

      // Observe logging status
      device.loggingDataTypes.observeChanges(4, (types) {
        List<String> activeTypes = [];
        if (types & DataTypeFlags.stepData != 0) activeTypes.add('Step');
        if (types & DataTypeFlags.rawIMU != 0) activeTypes.add('IMU');
        if (types & DataTypeFlags.rawFSR != 0) activeTypes.add('FSR');

        print('Currently logging: ${activeTypes.join(', ')}');
      });
    }
  }

  /// Example 4: File cleanup workflow
  Future<void> fileCleanupWorkflow(LFLiner device) async {
    print('Starting file cleanup workflow...');

    // Get current file count
    await device.getNumberOfFiles();

    device.fileCount.observeChanges(5, (count) async {
      print('Device has $count files');

      if (count > 5) {
        // If too many files, erase the last few to free space
        print('Too many files, cleaning up...');

        // Erase last file (this frees memory space)
        bool erased = await device.eraseLastFile();
        if (erased) {
          print('Last file erased');
          // Check count again
          await device.getNumberOfFiles();
        }
      } else if (count == 0) {
        print('No files on device');
      }
    });
  }

  /// Example 5: Convenience methods
  Future<void> convenienceMethodsExample(LFLiner device) async {
    print('Using convenience methods...');

    // Start full logging (sets time + starts logging with all data types)
    bool started = await device.startFullLogging();
    if (started) {
      print('Full logging started with convenience method');
    }

    // Simulate logging
    await Future.delayed(const Duration(seconds: 5));

    // Stop logging and immediately get file count
    bool stopped = await device.stopLoggingAndGetFiles();
    if (stopped) {
      print('Logging stopped and file count requested');
    }
  }

  /// Example 6: Error handling and status monitoring
  Future<void> statusMonitoringExample(LFLiner device) async {
    print('Setting up status monitoring...');

    // Monitor device messages for status updates
    device.message.observeChanges(6, (message) {
      print('Device message: $message');
    });

    // Monitor logging status
    device.loggingDataTypes.observeChanges(7, (types) {
      if (types == 0) {
        print('Device is not logging');
      } else {
        print('Device is logging with data types: $types');
      }
    });

    // Monitor file operations
    device.fileCount.observeChanges(8, (count) {
      print('File count updated: $count');
    });
  }

  /// Clean up observers when done
  void cleanup(LFLiner device) {
    device.removeAllRelevantObservers(1);
    device.removeAllRelevantObservers(2);
    device.removeAllRelevantObservers(3);
    device.removeAllRelevantObservers(4);
    device.removeAllRelevantObservers(5);
    device.removeAllRelevantObservers(6);
    device.removeAllRelevantObservers(7);
    device.removeAllRelevantObservers(8);
    print('Observers cleaned up');
  }
}
