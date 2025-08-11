# LAAF Protocol Update - File Management & Enhanced Logging

This document describes the new file management and enhanced logging capabilities added to the LAAF Blue plugin (version 0.0.3+).

## 🆕 What's New

The LAAF devices now support **onboard memory storage** and **file management**, allowing for:
- **Offline data collection** - devices can log data independently
- **Persistent storage** - data is saved to device memory until retrieved
- **Flexible data types** - choose which sensors to log (Step, IMU, FSR)
- **File management** - retrieve, erase, and manage stored files
- **Summary files** - quick access to device statistics

## 🔧 New Classes & Utilities

### DataTypeFlags
Constants for specifying which data types to log:
```dart
import 'package:blue/data_type_flags.dart';

// Individual data types
DataTypeFlags.stepData  // 0x01 - Step analysis data
DataTypeFlags.rawIMU    // 0x02 - Raw IMU sensor data  
DataTypeFlags.rawFSR    // 0x04 - Raw FSR pressure data

// Combined data types
DataTypeFlags.all           // 0x07 - All data types
DataTypeFlags.stepAndIMU    // 0x03 - Step + IMU
DataTypeFlags.stepAndFSR    // 0x05 - Step + FSR
DataTypeFlags.imuAndFSR     // 0x06 - IMU + FSR
```

### FileMetadata
Represents files stored on LAAF devices:
```dart
import 'package:blue/file_metadata.dart';

FileMetadata file = FileMetadata(
  index: 1,
  size: 1024,
  timestamp: DateTime.now(),
  dataTypes: [0x01, 0x04], // Step + FSR data
);

print(file.getDataTypesDescription()); // "Step, FSR"
```

## 📱 New LFLiner Methods

### Time Synchronization
```dart
// Set device time (required before logging)
await device.setTime(); // Uses current time
await device.setTime(timestamp: DateTime.now()); // Custom time
```

### Enhanced Logging
```dart
// Start logging with specific data types
await device.startLogging(DataTypeFlags.all);
await device.startLogging(DataTypeFlags.stepData | DataTypeFlags.rawFSR);

// Stop logging (required before file retrieval)
await device.stopLogging();

// Convenience method: set time + start logging
await device.startFullLogging();
```

### File Management
```dart
// Get number of files on device
await device.getNumberOfFiles();
// Result available in: device.fileCount.value()

// Download a specific file (1-based indexing)
await device.getFile(1);
// Data streams through: device.fileData observable

// Get quick summary file
await device.getSummaryFile();
// Data available in: device.summaryFile observable
```

### File Operations
```dart
// Erase specific file (changes indices of remaining files)
await device.eraseFile(2);

// Erase last file (only way to free memory space)
await device.eraseLastFile();

// Erase all files (format device)
await device.eraseAllFiles();

// Convenience: stop logging + get file count
await device.stopLoggingAndGetFiles();
```

## 📊 New Observables

Each LFLiner device now has additional observables for file management:

```dart
// File management observables
device.fileCount.observeChanges(id, (count) => print('$count files'));
device.fileList.observeChanges(id, (files) => print('Files: $files'));
device.fileData.observeChanges(id, (data) => print('${data.length} bytes'));
device.summaryFile.observeChanges(id, (summary) => processData(summary));
device.loggingDataTypes.observeChanges(id, (types) => print('Logging: $types'));
```

## 🔄 Typical Workflow

### 1. Basic Logging Session
```dart
// 1. Set device time
await device.setTime();

// 2. Start logging
await device.startLogging(DataTypeFlags.all);

// 3. Let device collect data...
await Future.delayed(Duration(minutes: 10));

// 4. Stop logging
await device.stopLogging();

// 5. Check how many files were created
await device.getNumberOfFiles();
```

### 2. File Retrieval
```dart
// Get file count first
await device.getNumberOfFiles();

device.fileCount.observeChanges(1, (count) async {
  print('Device has $count files');
  
  // Download each file
  for (int i = 1; i <= count; i++) {
    await device.getFile(i);
  }
});

// Monitor file downloads
device.fileData.observeChanges(2, (data) {
  // Process file data as it arrives
  processFileData(data);
});
```

### 3. Memory Management
```dart
// Check file count
await device.getNumberOfFiles();

device.fileCount.observeChanges(3, (count) async {
  if (count > 10) {
    // Too many files, clean up by erasing last files
    await device.eraseLastFile();
    await device.getNumberOfFiles(); // Check again
  }
});
```

## ⚠️ Important Notes

### File Index Management
- **File indices are 1-based** (not 0-based)
- **Erasing files changes indices** of remaining files
- **Only erasing the last file frees memory space**
- Use `eraseLastFile()` repeatedly to free maximum space

### Memory Behavior
- Device **stops logging when memory is full**
- **No automatic overwriting** of old data
- Must **stop logging before retrieving files**
- **Last file must be erased** to free space for new data

### Data Types & Packet Formats
- **Step Data** (0xD5): 24 bytes with relative timestamps
- **Raw IMU** (0xD0): 19 bytes with Unix timestamps  
- **Raw FSR** (0xE0): 21 bytes with Unix timestamps
- All stored data uses **Little-Endian** format

## 🧪 Example Usage

See `laaf_protocol_example.dart` for comprehensive examples including:
- Basic logging workflow
- File management operations
- Selective data type logging
- File cleanup procedures
- Error handling and status monitoring

## 🔧 Platform Implementation

The new protocol requires platform-specific implementation of these method channel calls:
- `setTime` - Set device timestamp
- `startLogging` - Begin data collection with flags
- `stopLogging` - End data collection
- `getNumberOfFiles` - Query file count
- `getFile` - Retrieve file by index
- `eraseFile` / `eraseLastFile` / `eraseAllFiles` - File deletion
- `getSummaryFile` - Get device summary

## 📈 Migration from v0.0.2

Existing code will continue to work. New features are additive:

**Old way (still works):**
```dart
await device.startLog();  // Basic logging
await device.stopLog();   // Stop logging
```

**New way (recommended):**
```dart
await device.setTime();                           // Set time first
await device.startLogging(DataTypeFlags.all);     // Enhanced logging
await device.stopLogging();                       // Stop logging
await device.getNumberOfFiles();                  // Check files
```

The new protocol significantly expands the capabilities of LAAF devices from live-streaming-only to a full offline data logging system with comprehensive file management.
