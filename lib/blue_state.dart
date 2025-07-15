import 'bluetooth_status.dart';
import 'lf_liner.dart';
import 'observable.dart';
import 'step_data_calculator.dart';

class BlueState {
  /// The status of the phone's bluetooth capabilities [uninitialized,
  /// available, or unavailable].
  Observable<BluetoothStatus> bluetoothStatus = Observable(BluetoothStatus.uninitialized, "bluetooth status");

  /// 'true' if the phone is currently scanning for bluetooth devices.
  Observable<bool> scanning = Observable(false, "scanning");

  /// General messages from the platform bluetooth.
  Observable<String> blueMessage = Observable("", "b msg");

  /// The devices detected in the last bluetooth scan.
  Observable<List<LFLiner>> scannedDevices = Observable(List.empty(), "scanned devices");

  /// Devices chosen for connection.  Though they are not necessarily connected
  /// [see LFLiner's 'deviceStatus' variable].  Devices are placed here after
  /// a connection attempt is made.
  Observable<List<LFLiner>> activeDevices = Observable([], "connected devices");

  /// Steps recorded by the plugin to calculate data points that require comparison
  /// of data from both sides.
  StepDataCalculator stepDataCalculator = StepDataCalculator(6);
}
