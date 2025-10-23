# IMU Data Usage Guide

This guide explains how to collect and use IMU (Inertial Measurement Unit) data from LAAF insoles.

## Overview

The LAAF insoles support raw IMU data collection, which includes:
- **3-axis Accelerometer** data (X, Y, Z) in g units
- **3-axis Gyroscope** data (X, Y, Z) in degrees/second
- **Unix timestamps** with millisecond precision

## IMU Data Packet Format

- **Packet ID**: `0xD0` (208 in decimal)
- **Packet Size**: 19 bytes
- **Byte Format**: Little-Endian
- **Scaling**: 16,384 AD/g @ 2g range

### Packet Structure

| Bytes | Data Type | Description |
|-------|-----------|-------------|
| 0 | Packet ID | 0xD0 |
| 1-4 | Timestamp (seconds) | Unix timestamp (seconds since 1970) |
| 5-6 | Timestamp (milliseconds) | Milliseconds component |
| 7-8 | Acc X | Raw accelerometer X (16-bit signed) |
| 9-10 | Acc Y | Raw accelerometer Y (16-bit signed) |
| 11-12 | Acc Z | Raw accelerometer Z (16-bit signed) |
| 13-14 | Gyro X | Raw gyroscope X (16-bit signed) |
| 15-16 | Gyro Y | Raw gyroscope Y (16-bit signed) |
| 17-18 | Gyro Z | Raw gyroscope Z (16-bit signed) |

## How to Get IMU Data

### 1. Import Required Classes

```dart
import 'package:blue/blue.dart';
import 'package:blue/data_type_flags.dart';
import 'package:blue/imu_packet.dart';
import 'package:blue/lf_liner.dart';
```

### 2. Enable IMU Logging

```dart
// Log only IMU data
await device.startLogging(DataTypeFlags.rawIMU);

// Log IMU + Step data
await device.startLogging(DataTypeFlags.stepAndIMU);

// Log all data types (Step + IMU + FSR)
await device.startLogging(DataTypeFlags.all);
```

### 3. Complete IMU Data Collection Workflow

```dart
// Connect to device
await device.connect();

// Set device time (required before logging)
await device.setTime();

// Start logging with IMU data
await device.startLogging(DataTypeFlags.rawIMU);

// Let device collect data
await Future.delayed(Duration(minutes: 5));

// Stop logging
await device.stopLogging();

// Check how many files were created
await device.getNumberOfFiles();

// Download the file
await device.getFile(1);
```

### 4. Monitor Live IMU Streaming

```dart
// Observe live IMU packets during streaming
device.imuPacket.observeChanges(1, (imuData) {
  print('IMU Timestamp: ${imuData.timestamp}');
  print('Acceleration: X=${imuData.accX}g, Y=${imuData.accY}g, Z=${imuData.accZ}g');
  print('Gyroscope: X=${imuData.gyroX}°/s, Y=${imuData.gyroY}°/s, Z=${imuData.gyroZ}°/s');
});

// Start streaming
await device.startStream();
```

### 5. Parse IMU Data from Downloaded Files

```dart
// Observe file downloads
device.fileData.observeChanges(2, (fileData) {
  // Parse the file data to extract all packets
  List<Map<String, dynamic>> packets = device.parseFileData(fileData);
  
  // Filter for IMU packets only
  var imuPackets = packets.where((packet) => 
    packet['packetType'] == 'imuData').toList();
  
  print('Found ${imuPackets.length} IMU packets');
  
  // Process each IMU packet
  for (var packet in imuPackets) {
    if (packet.containsKey('error')) {
      print('Error parsing packet: ${packet['error']}');
      continue;
    }
    
    // Access IMU data
    double timestamp = packet['timestampSeconds'] + 
                      (packet['timestampMilliseconds'] / 1000.0);
    double accX = packet['accX'];
    double accY = packet['accY'];
    double accZ = packet['accZ'];
    double gyroX = packet['gyroX'];
    double gyroY = packet['gyroY'];
    double gyroZ = packet['gyroZ'];
    
    print('IMU Data @ $timestamp: Acc=[$accX, $accY, $accZ]g, '
          'Gyro=[$gyroX, $gyroY, $gyroZ]°/s');
  }
});

// Request file download
await device.getFile(1);
```

## Complete Example

```dart
import 'package:blue/blue.dart';
import 'package:blue/data_type_flags.dart';
import 'package:blue/imu_packet.dart';
import 'package:blue/lf_liner.dart';

class IMUDataCollector {
  final Blue blue = Blue();
  
  Future<void> collectIMUData(LFLiner device) async {
    print('Starting IMU data collection...');
    
    // 1. Set device time
    bool timeSet = await device.setTime();
    if (!timeSet) {
      print('Failed to set device time');
      return;
    }
    print('Device time synchronized');
    
    // 2. Start logging with IMU data
    bool loggingStarted = await device.startLogging(DataTypeFlags.rawIMU);
    if (!loggingStarted) {
      print('Failed to start IMU logging');
      return;
    }
    print('IMU logging started');
    
    // 3. Let device collect data
    print('Collecting IMU data for 30 seconds...');
    await Future.delayed(const Duration(seconds: 30));
    
    // 4. Stop logging
    bool loggingStopped = await device.stopLogging();
    if (!loggingStopped) {
      print('Failed to stop logging');
      return;
    }
    print('Logging stopped');
    
    // 5. Get file count
    await device.getNumberOfFiles();
    
    // 6. Set up file download observer
    device.fileCount.observeChanges(1, (count) async {
      print('Device has $count files');
      
      if (count > 0) {
        // Set up data observer
        device.fileData.observeChanges(2, (fileData) {
          processIMUFile(device, fileData);
        });
        
        // Download the first file
        await device.getFile(1);
      }
    });
  }
  
  void processIMUFile(LFLiner device, Uint8List fileData) {
    print('Processing IMU file (${fileData.length} bytes)...');
    
    // Parse all packets from the file
    List<Map<String, dynamic>> packets = device.parseFileData(fileData);
    
    // Filter and process IMU packets
    var imuPackets = packets.where((p) => p['packetType'] == 'imuData').toList();
    
    print('Found ${imuPackets.length} IMU packets');
    
    // Calculate some statistics
    if (imuPackets.isNotEmpty) {
      double avgAccX = imuPackets
          .map((p) => p['accX'] as double)
          .reduce((a, b) => a + b) / imuPackets.length;
      
      double avgAccY = imuPackets
          .map((p) => p['accY'] as double)
          .reduce((a, b) => a + b) / imuPackets.length;
      
      double avgAccZ = imuPackets
          .map((p) => p['accZ'] as double)
          .reduce((a, b) => a + b) / imuPackets.length;
      
      print('Average Acceleration:');
      print('  X: ${avgAccX.toStringAsFixed(3)}g');
      print('  Y: ${avgAccY.toStringAsFixed(3)}g');
      print('  Z: ${avgAccZ.toStringAsFixed(3)}g');
    }
    
    // Export or save data
    exportIMUData(imuPackets);
  }
  
  void exportIMUData(List<Map<String, dynamic>> imuPackets) {
    // Export to CSV, database, or process for analysis
    print('Exporting ${imuPackets.length} IMU packets...');
    
    // Example: Convert to CSV format
    StringBuffer csv = StringBuffer();
    csv.writeln('timestamp,accX,accY,accZ,gyroX,gyroY,gyroZ');
    
    for (var packet in imuPackets) {
      double timestamp = packet['timestampSeconds'] + 
                        (packet['timestampMilliseconds'] / 1000.0);
      csv.writeln('$timestamp,'
                 '${packet['accX']},'
                 '${packet['accY']},'
                 '${packet['accZ']},'
                 '${packet['gyroX']},'
                 '${packet['gyroY']},'
                 '${packet['gyroZ']}');
    }
    
    print('CSV data ready for export');
    // Save csv.toString() to file or upload to server
  }
  
  void cleanup(LFLiner device) {
    device.fileCount.removeRelevantObservers(1);
    device.fileData.removeRelevantObservers(2);
  }
}
```

## Important Notes

### 1. Data Collection Modes

- **Logged Data**: IMU data saved to device memory during logging sessions
  - Use `startLogging(DataTypeFlags.rawIMU)` to enable
  - Data persists until explicitly erased
  - Must stop logging before retrieving files

- **Live Streaming**: IMU data streamed in real-time (if supported by firmware)
  - Use `startStream()` to enable
  - Observe via `device.imuPacket` observable
  - No persistent storage

### 2. Data Format

- **Accelerometer**: Values in g units (1g ≈ 9.81 m/s²)
  - Range: ±2g
  - Resolution: 16,384 counts per g
  
- **Gyroscope**: Values in degrees/second
  - Follow same scaling as accelerometer per documentation

### 3. Sampling Rate

The IMU sampling rate depends on the device firmware configuration. FSR and IMU data can be sampled at different rates.

### 4. Memory Management

- Files are stored on device until explicitly erased
- Check file count regularly: `await device.getNumberOfFiles()`
- Free space by erasing last file: `await device.eraseLastFile()`
- Device stops logging when memory is full

### 5. Time Synchronization

Always call `device.setTime()` before starting logging to ensure accurate timestamps.

## Troubleshooting

### No IMU data in files
- Verify IMU flag was set: `DataTypeFlags.rawIMU` or `DataTypeFlags.all`
- Check that logging actually started (monitor `device.loggingDataTypes`)
- Ensure device firmware supports IMU logging

### Timestamp issues
- Call `setTime()` before each logging session
- Device uses Unix timestamps (seconds since 1970-01-01)

### Memory full
- Download and erase old files before new logging sessions
- Use `eraseLastFile()` repeatedly to free space
- Consider `eraseAllFiles()` for complete cleanup

## See Also

- `LAAF_PROTOCOL_UPDATE.md` - Complete protocol documentation
- `laaf_protocol_example.dart` - General logging examples
- `data_type_flags.dart` - Data type flag constants
- `imu_packet.dart` - IMU packet class implementation
