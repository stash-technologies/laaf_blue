/// Data type flags for LAAF logging commands
/// These flags can be combined using bitwise OR operations
class DataTypeFlags {
  /// Step data logging flag
  static const int stepData = 0x01;
  
  /// Raw IMU data logging flag  
  static const int rawIMU = 0x02;
  
  /// Raw FSR data logging flag
  static const int rawFSR = 0x04;
  
  /// All data types combined
  static const int all = stepData | rawIMU | rawFSR; // 0x07
  
  /// Step data and IMU data combined
  static const int stepAndIMU = stepData | rawIMU; // 0x03
  
  /// Step data and FSR data combined
  static const int stepAndFSR = stepData | rawFSR; // 0x05
  
  /// IMU and FSR data combined
  static const int imuAndFSR = rawIMU | rawFSR; // 0x06
}
