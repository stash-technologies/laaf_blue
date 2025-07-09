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
        peripheral.discoverCharacteristics([uuids!.command, uuids!.data, uuids!.mode, uuids!.liveStream], for: peripheral.services![0])
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        flutterMessage("characteristics discovered")
        
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
        flutterMessage("successfully enabled notifications for: \(parseChararcteristic(characteristic: characteristic)) characteristic: \(characteristic.isNotifying)")
        
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
        //flutterMessage("new value for \(peripheral.identifier.uuidString) \(parseChararcteristic(characteristic: characteristic)) characteristic: \(characteristic.value!.map { String(format: "%02x", $0)}.joined())", peripheral.identifier.uuidString)
        
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
        
        flutterMessage("new value written for \(peripheral.identifier.uuidString) \(parseChararcteristic(characteristic: characteristic)) characteristic: \(val)", peripheral.identifier.uuidString)
        
        if (characteristic == commandChar) {
            writeResult!(true)
        }
    }
    
    func parseChararcteristic(characteristic: CBCharacteristic) -> String{
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
