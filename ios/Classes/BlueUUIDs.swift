//
//  BlueUUIDs.swift
//  blue
//
//  Created by Dylan on 11/8/23.
//

import Foundation

import CoreBluetooth

//TODO => constructor / exploder that makes it easier to move to and
// from list form (services vs characteristics)

struct BlueUUIDs {
    var service: CBUUID
    var command: CBUUID
    var data: CBUUID
    var mode: CBUUID
    var liveStream: CBUUID
    var dfuTarget: CBUUID
}
