import Flutter
import UIKit

import CoreBluetooth

public class BluePlugin: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate, FlutterPlugin {
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "blue", binaryMessenger: registrar.messenger())
        let instance = BluePlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        fChannel = channel
    }
    
    static var fChannel: FlutterMethodChannel!
    
    var centralManager: CBCentralManager!
    
    
    var bluetoothResult: FlutterResult?
    
    var discoveredDevices: Array<CBPeripheral> = Array()
    var connectedDevices: Array<LFLiner> = Array()
    
    var uuids: BlueUUIDs?
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
            
        case "initializeBluetooth":
            flutterMessage("initializing bluetooth...")
            
            let buuids = call.arguments as! Array<String>

            uuids = BlueUUIDs(service: CBUUID(string: buuids[0]), command: CBUUID(string: buuids[1]),
                              data: CBUUID(string: buuids[2]), mode: CBUUID(string: buuids[3]),liveStream: CBUUID(string: buuids[4]), dfuTarget: CBUUID(string: buuids[5]))
            
            centralManager = CBCentralManager(delegate:self, queue: nil, options: nil)
            
            result(true)
            
            // picked up again in 'centraManagerDidUpdateState'...
        case "scan":
            flutterMessage("ios scan")
            if (centralManager.isScanning) {
                flutterMessage("you are already scanning!")
                result(false)
            } else {
                discoveredDevices = Array()
                // discoveredDevices will always be empty at this point...
                BluePlugin.fChannel.invokeMethod("updateDetectedDevices",
                                                 arguments: self.discoveredDevices.map
                                                 { LFLiner(id: $0.identifier.uuidString, name: $0.name!).toHashmap() })
                
                // Handle scan arguments - can be int (legacy) or dictionary (new)
                var onlyDfuDevices = false
                if let scanArgs = call.arguments as? [String: Any] {
                    onlyDfuDevices = scanArgs["onlyDfuDevices"] as? Bool ?? false
                }
                
                // Choose which service UUID to scan for
                let serviceToScan = onlyDfuDevices ? uuids!.dfuTarget : uuids!.service
                centralManager.scanForPeripherals(withServices: [serviceToScan])
                
                let scanType = onlyDfuDevices ? "DFU devices" : "LAAF devices"
                flutterMessage("Scanning for \(scanType)")
                result(true)
            }
        case "stopScan":
            centralManager.stopScan()
            flutterMessage("scan complete")
            result(true)
            
        case "connect":
            let deviceID = call.arguments as! String
            
            let selectedPeripheral = discoveredDevices.first(where: {$0.identifier.uuidString == deviceID})
            
            if (selectedPeripheral == nil) {
                result(false)
                break
            }
            
            centralManager.connect(selectedPeripheral!)
            result(true)
            
        case "checkMode":
            let deviceId = call.arguments as! String
            // TODO => is this naming sloppy? should it be check device 'mode?' or 'state'?
            checkDeviceState(deviceId)
            result(true)
            
        case "disconnect":
            let deviceId = call.arguments as! String
            
            let device = discoveredDevices.first(where: {$0.identifier.uuidString == deviceId})
            
            if (device == nil) {
                result(false)
                flutterMessage("couldn't find device with id: \(deviceId)")
                break
            }
            
            centralManager.cancelPeripheralConnection(device!)
            
            result(true)
            
        case "sendCommand":
            // TODO => this needs a refactor to cover devices that are no longer available
            // or have suddenly disconnected (without crashing the app!)
            let args = call.arguments as! Dictionary<String, Any?>
            let rawFlutterData = args["command"] as! FlutterStandardTypedData
            
            let data = Data(rawFlutterData.data)
            
            let deviceId = args["device"] as! String
            //let device = discoveredDevices.first(where: {$0.identifier.uuidString == deviceId})!
            let device = connectedDevices.first(where: {$0.id == deviceId})!
            
            flutterMessage("writing command: ...\(device.id.suffix(4)) => \(data.map { String(format: "[%02x]", $0)}.joined())", device.id)
            
            // this is where timeout timer should be started...
            device.writeResult = result
            writeCommand(liner: device, command: data)
            
            // TODO => this 'discoveredDevices' vs 'connectedDevices' feels a little loose logically, clean it up
            
        case "getMacAddress":
            let deviceId = call.arguments as! String
            let macAddress = getMacAddress(deviceId: deviceId)
            result(macAddress)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    func getMacAddress(deviceId: String) -> String? {
        // Find the connected device
        let device = connectedDevices.first(where: {$0.id == deviceId})
        
        if let peripheral = device?.peripheral {
            // On iOS, we can't get the actual MAC address due to privacy restrictions
            // Instead, we return the device identifier UUID which is unique per device per app
            // For DFU purposes, this UUID can be used as a unique identifier
            return peripheral.identifier.uuidString
        }
        
        return nil
    }
    
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("new bluetooth state...\(central.state.rawValue)")
        if (central.state == .poweredOn) {
            BluePlugin.fChannel.invokeMethod("bluetoothStateUpdate", arguments: 1)
        } else {
            BluePlugin.fChannel.invokeMethod("bluetoothStateUpdate", arguments: 2)
            connectedDevices.removeAll()
            discoveredDevices.removeAll()
            
            BluePlugin.fChannel.invokeMethod("updateDetectedDevices",
                                             arguments: self.discoveredDevices.map
                                             { LFLiner(id: $0.identifier.uuidString, name: $0.name!).toHashmap() })
        }
    }
    
    public func centralManager(_ central: CBCentralManager,
                               didDiscover peripheral: CBPeripheral,
                               advertisementData: [String : Any], rssi RSSI: NSNumber) {
       
        if (!discoveredDevices.contains(peripheral)) {
            discoveredDevices.append(peripheral)
           
            BluePlugin.fChannel.invokeMethod("updateDetectedDevices",
                                             arguments: self.discoveredDevices.map
                                             { LFLiner(id: $0.identifier.uuidString, name: $0.name!).toHashmap() })
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        flutterMessage("device connection initiated...")
        let liner = LFLiner(id: peripheral.identifier.uuidString, name: peripheral.name!)
        liner.peripheral = peripheral 
        liner.uuids = uuids
        connectedDevices.append(liner)
        
        peripheral.delegate = liner
        
        // Check if this is a DFU device by looking for DFU service
        // If it has DFU service, handle it as DFU device, otherwise as LAAF device
        peripheral.discoverServices([uuids!.service, uuids!.dfuTarget])
    }
    
    //TODO => these should check for errors (even though I've never had one)
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        flutterMessage("\(peripheral.name!) succesfully disconnected.")
        BluePlugin.fChannel.invokeMethod("deviceDisconnected", arguments: peripheral.identifier.uuidString)
        
        connectedDevices.removeAll(where: {$0.id == peripheral.identifier.uuidString})
        flutterMessage("remaining devices : \(connectedDevices)")
    }
    
    private func flutterMessage(_ message: String, _ id: String = "general") {
        BluePlugin.fChannel.invokeMethod("flutterMessage", arguments: ["id" : id, "message" : message])
    }
    
    //TODO => this should take the result...
    public func writeCommand(liner: LFLiner, command: Data) {
        //let liner = connectedDevices.first(where: {$0.id == device.identifier.uuidString})!
        
        liner.peripheral!.writeValue(command, for: liner.commandChar, type: .withResponse);
    }
    
    public func checkDeviceState(_ id: String) {
        flutterMessage("checking device state...", id)
        
        let liner = connectedDevices.first(where: {$0.id == id})
        
        if (liner != nil) {
            discoveredDevices.first(where: {$0.identifier.uuidString == id})!.readValue(for: liner!.modeChar)
        }
    }
}

/**
  Can I do something (clean) about managing 'result' scope and storage? or should I abandon it and stick
 with observers and result callbacks built in to the api...maybe I can find a balance? maybe I can store callbacks
 within the library itself? instead of on observers?
    => result functions will return whether or not the command was succesfully sent (ie, no weird bugs, or disconnected
 devices, that kind of thing).  But the actual result of the function / command will return through the appropriate observable/function
*/
