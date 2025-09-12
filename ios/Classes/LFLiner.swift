//
//  LFLiner.swift
//  blue
//
//  Created by Dylan on 11/8/23.
//

import Foundation

import CoreBluetooth
import Flutter

public class LFLiner: NSObject, CBPeripheralDelegate  {
    var id: String
    var name: String
    
    var peripheral: CBPeripheral?
    
    // this needs some kind of timeout, and some form of id to determine
    // which result to use... [keep it simple though]
    var writeResult: FlutterResult?
    
    init(id: String, name: String) {
        self.id = id
        self.name = name
    }
    
    var uuids: BlueUUIDs!
    
    var liveStreamChar: CBCharacteristic!
    var modeChar: CBCharacteristic!
    var commandChar: CBCharacteristic!
    var dataChar: CBCharacteristic!
    
    func toHashmap() -> [String: Any]{
        return ["id" : id, "name": name]
    }
    
    //TODO => the peripheral needs to be refactored as well, so that the single delegate can be copied
    // to serve individual liners simultaneously
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        flutterMessage("services discovered")
        
        // Discover characteristics for all services
        for service in peripheral.services! {
            if service.uuid == uuids!.service {
                // LAAF service - discover main characteristics
                peripheral.discoverCharacteristics([uuids!.command, uuids!.data, uuids!.mode, uuids!.liveStream], for: service)
            } else if service.uuid == CBUUID(string: "180A") {
                // Device Information Service - discover firmware revision characteristic
                peripheral.discoverCharacteristics([CBUUID(string: "2A26")], for: service)
            }
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        flutterMessage("characteristics discovered")
        
        if service.uuid == uuids!.service {
            // Handle LAAF service characteristics
            for c in service.characteristics! {
                switch (c.uuid) {
                case uuids!.command:
                    commandChar = c
                case uuids!.data:
                    dataChar = c
                case uuids!.mode:
                    modeChar = c
                case uuids!.liveStream:
                    liveStreamChar = c
                default:
                    continue
                }
            }
            // subscribing for notifications
            peripheral.setNotifyValue(true, for: dataChar)
            peripheral.setNotifyValue(true, for: modeChar)
            peripheral.setNotifyValue(true, for: liveStreamChar)
        } else if service.uuid == CBUUID(string: "180A") {
            // Handle Device Information Service
            for c in service.characteristics! {
                if c.uuid == CBUUID(string: "2A26") {
                    // Read firmware revision string automatically
                    peripheral.readValue(for: c)
                }
            }
        }
    }
    
    class BluetoothConnectionProgress {
        var dataCharNotificationEnabled = false
        var modeCharNotificationEnabled = false
        var liveStreamCharNotificationEnabled = false
        
        func complete() -> Bool { return dataCharNotificationEnabled && modeCharNotificationEnabled && liveStreamCharNotificationEnabled}
        func reset() {
            self.dataCharNotificationEnabled = false
            self.modeCharNotificationEnabled = false
            self.liveStreamCharNotificationEnabled = false
        }
    }
    
    var bluetoothConnectionProgress = BluetoothConnectionProgress()
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        flutterMessage("successfully enabled notifications for: \(parseCharacteristic(characteristic: characteristic)) characteristic: \(characteristic.isNotifying)")
        
        switch (characteristic) {
        case dataChar:
            bluetoothConnectionProgress.dataCharNotificationEnabled = true
        case modeChar:
            bluetoothConnectionProgress.modeCharNotificationEnabled = true
        case liveStreamChar:
            bluetoothConnectionProgress.liveStreamCharNotificationEnabled = true
        default:
            break
        }
        
        if (bluetoothConnectionProgress.complete()) {
            flutterMessage("connection complete", peripheral.identifier.uuidString)
            BluePlugin.fChannel.invokeMethod("connectionComplete", arguments: peripheral.identifier.uuidString)
            bluetoothConnectionProgress.reset()
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        //flutterMessage("new value for \(peripheral.identifier.uuidString) \(parseCharacteristic(characteristic: characteristic)) characteristic: \(characteristic.value!.map { String(format: "%02x", $0)}.joined())", peripheral.identifier.uuidString)
        
        if (characteristic == modeChar) {
            var deviceStateInt = characteristic.value![0]
            // sometimes (after firmware update), you can get garbage here
            if (deviceStateInt > 1) {
                deviceStateInt = 0
            }
            
            // +1 to align with flutter side enum
            BluePlugin.fChannel.invokeMethod("updateDeviceState", arguments: ["id": peripheral.identifier.uuidString, "state" : deviceStateInt + 1])
        }
        
        if (characteristic == liveStreamChar) {
            BluePlugin.fChannel.invokeMethod("liveStreamPacket", arguments: ["id": peripheral.identifier.uuidString, "packet": characteristic.value!])
        }
        
        // Handle firmware version read from Device Information Service
        if (characteristic.uuid == CBUUID(string: "2A26")) {
            if let firmwareData = characteristic.value,
               let firmwareVersion = String(data: firmwareData, encoding: .utf8) {
                flutterMessage("firmware version read: \(firmwareVersion)", peripheral.identifier.uuidString)
                BluePlugin.fChannel.invokeMethod("firmwareVersionRead", arguments: ["id": peripheral.identifier.uuidString, "version": firmwareVersion])
            }
        }
        
        // Handle new LAAF protocol file management responses
        if (characteristic == dataChar) {
            guard let data = characteristic.value else { return }
            
            // Log all incoming data for debugging
            let dataHex = data.map { String(format: "%02x", $0) }.joined()
            flutterMessage("Raw data received: \(dataHex)", peripheral.identifier.uuidString)
            
            // Skip empty data
            if data.count == 0 { return }
            
            let commandId = data[0]
            
            switch commandId {
            case 0x20: // Response to "get number of files" command
                if data.count >= 2 {
                    let fileCount = Int(data[1])
                    flutterMessage("Device has \(fileCount) files", peripheral.identifier.uuidString)
                    BluePlugin.fChannel.invokeMethod("fileCountResponse", arguments: [
                        "id": peripheral.identifier.uuidString,
                        "count": fileCount
                    ])
                } else {
                    flutterMessage("Invalid file count response format", peripheral.identifier.uuidString)
                }
                
            case 0x21: // Response to "get file" command - file data chunk
                if data.count > 1 {
                    let fileData = data.subdata(in: 1..<data.count)
                    flutterMessage("Received file data chunk (\(fileData.count) bytes)", peripheral.identifier.uuidString)
                    BluePlugin.fChannel.invokeMethod("fileDataChunk", arguments: [
                        "id": peripheral.identifier.uuidString,
                        "chunk": fileData,
                        "isComplete": false // You may need to determine this based on your protocol
                    ])
                }
                
            case 0x10: // Response to "get summary file" command
                if data.count > 1 {
                    let summaryData = data.subdata(in: 1..<data.count)
                    flutterMessage("Received summary file (\(summaryData.count) bytes)", peripheral.identifier.uuidString)
                    BluePlugin.fChannel.invokeMethod("summaryFileResponse", arguments: [
                        "id": peripheral.identifier.uuidString,
                        "data": summaryData
                    ])
                }
                
            case 0x22, 0x29: // Response to erase file commands
                let success = data.count > 1 ? data[1] == 0x01 : true
                let operation = commandId == 0x22 ? "eraseFile" : "eraseAllFiles"
                flutterMessage("File operation \(operation): \(success ? "success" : "failed")", peripheral.identifier.uuidString)
                BluePlugin.fChannel.invokeMethod("fileOperationComplete", arguments: [
                    "id": peripheral.identifier.uuidString,
                    "operation": operation,
                    "success": success
                ])
                
            case 0x01, 0x02: // Response to start/stop logging commands
                let isLogging = commandId == 0x01
                let dataTypes = data.count > 1 ? Int(data[1]) : 0
                
                // Validate data types - only accept valid LAAF protocol flags
                let validDataTypes = [0, 1, 2, 3, 4, 5, 6, 7] // Valid combinations of Step(1), IMU(2), FSR(4)
                
                if isLogging && !validDataTypes.contains(dataTypes) {
                    flutterMessage("Invalid data type flags: \(dataTypes) - ignoring spurious logging command", peripheral.identifier.uuidString)
                    break
                }
                
                // Only process if this looks like a legitimate command response
                // Real logging responses should be short (2-3 bytes max)
                if data.count > 3 {
                    flutterMessage("Logging response too long (\(data.count) bytes) - likely sensor data, ignoring", peripheral.identifier.uuidString)
                    break
                }
                
                flutterMessage("Logging status update: \(isLogging ? "started" : "stopped") with data types: \(dataTypes)", peripheral.identifier.uuidString)
                BluePlugin.fChannel.invokeMethod("loggingStatusUpdate", arguments: [
                    "id": peripheral.identifier.uuidString,
                    "isLogging": isLogging,
                    "dataTypes": dataTypes
                ])
                
            default:
                // Only log if it's a short packet that might be a command response
                // Ignore long sensor data packets
                if data.count <= 4 {
                    flutterMessage("Unknown command response: 0x\(String(format: "%02x", commandId)) (\(data.count) bytes)", peripheral.identifier.uuidString)
                }
            }
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if (error != nil) {
            print(error!.localizedDescription)
            return
        }
        
        var val = "nil"
        if (characteristic.value != nil) {
            val = characteristic.value!.map { String(format: "%02x", $0)}.joined()
        }
        
        flutterMessage("new value written for \(peripheral.identifier.uuidString) \(parseCharacteristic(characteristic: characteristic)) characteristic: \(val)", peripheral.identifier.uuidString)
        
        if (characteristic == commandChar) {
            writeResult!(true)
        }
    }
    
    func parseCharacteristic(characteristic: CBCharacteristic) -> String{
        var c = "?"
                
        switch (characteristic) {
        case commandChar:
            c = "command"
        case dataChar:
            c = "data"
        case modeChar:
            c = "mode"
        case liveStreamChar:
            c = "liveStream"
        default:
            c = "?"
        }
        
        return c
    }
    
    private func flutterMessage(_ message: String, _ id: String = "general") {
        BluePlugin.fChannel.invokeMethod("flutterMessage", arguments: ["id" : 
                                                                        id, "message" : message])
    }
}
