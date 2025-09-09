import 'dart:typed_data';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'blue_method_channel.dart';

import 'blue_state.dart';

abstract class BluePlatform extends PlatformInterface {
  /// Constructs a BluePlatform.
  BluePlatform() : super(token: _token);

  static final Object _token = Object();

  static BluePlatform _instance = MethodChannelBlue();

  /// The default instance of [BluePlatform] to use.
  ///
  /// Defaults to [MethodChannelBlue].
  static BluePlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [BluePlatform] when
  /// they register themselves.
  static set instance(BluePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<bool?> initializeBluetooth() {
    throw UnimplementedError('initializeBluetooth() has not been implemented');
  }

  Future<bool?> scan(int duration, {bool onlyDfuDevices = false}) {
    throw UnimplementedError('scan() has not been implemented');
  }

  Future<bool?> stopScan() {
    throw UnimplementedError('stopScan() has not been implemented');
  }

  Future<bool?> connect(String deviceId) {
    throw UnimplementedError('connect() has not been implemented');
  }

  Future<bool?> disconnect(String deviceId, {bool keepAround = true}) {
    throw UnimplementedError('disconnect() has not been implemented');
  }

  Future<bool?> checkMode(String deviceId) {
    throw UnimplementedError('checkMode() has not been implemented');
  }

  Future<bool?> sendCommand(String deviceId, Uint8List command) {
    throw UnimplementedError('sendCommand() has not been implemented');
  }

  Future<bool?> reset(String deviceId) {
    throw UnimplementedError('reset() has not been implemented');
  }

  // New LAAF protocol methods for file management and enhanced logging
  Future<bool?> setTime(String deviceId, DateTime timestamp) {
    throw UnimplementedError('setTime() has not been implemented');
  }

  Future<bool?> startLogging(String deviceId, int dataTypeFlags) {
    throw UnimplementedError('startLogging() has not been implemented');
  }

  Future<bool?> stopLogging(String deviceId) {
    throw UnimplementedError('stopLogging() has not been implemented');
  }

  Future<int?> getNumberOfFiles(String deviceId) {
    throw UnimplementedError('getNumberOfFiles() has not been implemented');
  }

  Future<bool?> getFile(String deviceId, int fileIndex) {
    throw UnimplementedError('getFile() has not been implemented');
  }

  Future<bool?> eraseFile(String deviceId, int fileIndex) {
    throw UnimplementedError('eraseFile() has not been implemented');
  }

  Future<bool?> eraseLastFile(String deviceId) {
    throw UnimplementedError('eraseLastFile() has not been implemented');
  }

  Future<bool?> eraseAllFiles(String deviceId) {
    throw UnimplementedError('eraseAllFiles() has not been implemented');
  }

  Future<bool?> getSummaryFile(String deviceId) {
    throw UnimplementedError('getSummaryFile() has not been implemented');
  }

  Future<bool?> enterDFUMode(String deviceId) {
    throw UnimplementedError('enterDFUMode() has not been implemented');
  }

  BlueState getBlueState() {
    return _instance.getBlueState();
  }
}
