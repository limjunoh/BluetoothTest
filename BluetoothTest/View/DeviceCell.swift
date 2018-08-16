//
//  DeviceCell.swift
//  BluetoothTestaddressCell
//
//  Created by 임준오 on 2018. 8. 9..
//  Copyright © 2018년 Junoh. All rights reserved.
//

import UIKit

// 디바이스 스캔 테이블 뷰 내 셀
class DeviceCell: UITableViewCell {
    @IBOutlet weak var name: UILabel!   // 디바이스 이름
    @IBOutlet weak var uuid: UILabel!   // 디바이스 UUID
}
