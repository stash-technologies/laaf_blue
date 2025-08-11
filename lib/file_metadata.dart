import 'dart:typed_data';

/// Represents metadata and content for a file stored on a LAAF device
class FileMetadata {
  final int index;
  final int size;
  final DateTime? timestamp;
  final String? filename;
  final List<int> dataTypes; // Which data types are included (step, IMU, FSR)
  Uint8List? content; // File content when downloaded
  bool isDownloading;
  double downloadProgress;

  FileMetadata({
    required this.index,
    required this.size,
    this.timestamp,
    this.filename,
    this.dataTypes = const [],
    this.content,
    this.isDownloading = false,
    this.downloadProgress = 0.0,
  });

  /// Create an empty file metadata
  static FileMetadata empty() {
    return FileMetadata(
      index: 0,
      size: 0,
    );
  }

  /// Check if this file contains step data
  bool hasStepData() => dataTypes.contains(0x01);

  /// Check if this file contains IMU data
  bool hasIMUData() => dataTypes.contains(0x02);

  /// Check if this file contains FSR data
  bool hasFSRData() => dataTypes.contains(0x04);

  /// Get a human-readable description of data types
  String getDataTypesDescription() {
    List<String> types = [];
    if (hasStepData()) types.add('Step');
    if (hasIMUData()) types.add('IMU');
    if (hasFSRData()) types.add('FSR');
    return types.isEmpty ? 'Unknown' : types.join(', ');
  }

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'size': size,
      'timestamp': timestamp?.toIso8601String(),
      'filename': filename,
      'dataTypes': dataTypes,
      'isDownloading': isDownloading,
      'downloadProgress': downloadProgress,
    };
  }

  /// Create from JSON
  static FileMetadata fromJson(Map<String, dynamic> json) {
    return FileMetadata(
      index: json['index'] ?? 0,
      size: json['size'] ?? 0,
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : null,
      filename: json['filename'],
      dataTypes: List<int>.from(json['dataTypes'] ?? []),
      isDownloading: json['isDownloading'] ?? false,
      downloadProgress: (json['downloadProgress'] ?? 0.0).toDouble(),
    );
  }

  @override
  String toString() {
    return 'FileMetadata{index: $index, size: $size, types: ${getDataTypesDescription()}, downloading: $isDownloading}';
  }
}
