//
//  SensorValues.swift
//  BluetoothTest
//
//  Created by jang on 2018. 8. 24..
//  Copyright © 2018년 Junoh. All rights reserved.
//

import Foundation
import Firebase
import CoreBluetooth


@objcMembers class SensorValue:NSObject{
    var values:[Double]
    
    init(values:[Double]) {
        self.values = values
    }
    convenience override init() {
        self.init(values:[])
    }
    
    func getValuse() -> [Double] {
        return self.values
    }
    
}
