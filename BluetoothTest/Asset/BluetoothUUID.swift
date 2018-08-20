//
//  BluetoothUUID.swift
//  BluetoothTest
//
//  Created by jang on 2018. 8. 21..
//  Copyright © 2018년 Junoh. All rights reserved.
//

import Foundation
import CoreBluetooth

class BluetoothUUID {
    let HM10_Service_CBUUID = CBUUID(string: "0xFFE0")
    let HM10_Characteristic_CBUUID = CBUUID(string: "0xFFE1")
    
    let BLE_Temperature_Service_CBUUID = CBUUID(string: "0x1809")
    let BLE_Temperature_Measurement_Characteristic_CBUUID = CBUUID(string: "0x2A1C")
}
