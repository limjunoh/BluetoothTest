//
//  TerminalViewController.swift
//  BluetoothTest
//
//  Created by 임준오 on 2018. 8. 9..
//  Copyright © 2018년 Junoh. All rights reserved.
//

import UIKit
import CoreBluetooth

// 터미널 컨트롤러
class TerminalViewController: UIViewController {

    @IBOutlet weak var deviceName: UITextField!
    @IBOutlet weak var terminal: UITextView!
    @IBOutlet weak var disconnectButton: UIButton!
    
    let date = DateFormatter()
    var isConnected: Bool = false {
        didSet {
            if isConnected == true {
                disconnectButton.isEnabled = true
            } else {
                disconnectButton.isEnabled = false
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        serial = BluetoothSerial(delegate: self)
        deviceName.isUserInteractionEnabled = false
        disconnectButton.isEnabled = false
        date.locale = Locale(identifier: "ko_kr")
        date.timeZone = TimeZone(abbreviation: "KST")
        date.dateFormat = "mm:ss:SS"    // 분:초:밀리초
        
        NotificationCenter.default.addObserver(self, selector: #selector(reloadView), name: NSNotification.Name(rawValue: "bluetoothStatusChanged"), object: nil)
        // NotificationCenter 객체 옵저버 달아서 DeviceViewController에서 bluetoothStatusChanged 이름으로 post
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        // 옵저버 제거
    }
    
    override func viewDidAppear(_ animated: Bool) {
        serial.delegate = self
    }

    // 옵저버가 post한 것을 받으면 이 함수가 실행됨
    @objc func reloadView() {
        serial.delegate = self
        
        if serial.isReady { // 연결 시
            let device = serial.connectedPeripheral?.name ?? "Unknown"
            deviceName.text = device
            isConnected = true
            terminal.text = terminal.text.appending("[" + date.string(from: Date()) + "] connected to " + device + "\n")
        } else {            // 연결 끊김
            isConnected = false
        }
    }
    
    // 터미널 클리어 액션
    @IBAction func clearAction(_ sender: UIButton) {
        terminal.text = ""
    }
    
    // 연결된 peripheral disconnect
    @IBAction func disconnectAction(_ sender: UIButton) {
        serial.disconnect()
        deviceName.text = ""
        isConnected = false
    }
}

// 블루투스 serial delegate
extension TerminalViewController: BluetoothSerialDelegate {
    func serialDidDiscoverPeripheral(_ peripheral: CBPeripheral, RSSI: NSNumber?) {
//        for existing in peripherals {
//            if existing.peripheral.identifier == peripheral.identifier { return }
//        }
//
//        let theRSSI = RSSI?.floatValue ?? 0.0
//        peripherals.append((peripheral: peripheral, RSSI: theRSSI))
//        peripherals.sort{ $0.RSSI < $1.RSSI }
//        tableView.reloadData()
    }
    
    func serialDidFailToConnect(_ peripheral: CBPeripheral, error: NSError?) {
        print("블루투스 연결 실패")
    }
    
    func serialDidDisconnect(_ peripheral: CBPeripheral, error: NSError?) {
        print("블루투스 연결이 끊어졌습니다")
    }
    
    func serialIsReady(_ peripheral: CBPeripheral) {
        NotificationCenter.default.post(name: Notification.Name(rawValue: "reloadStartViewController"), object: self)
    }
    
    func serialDidChangeState() {
        if serial.centralManager.state != .poweredOn {
            NotificationCenter.default.post(name: Notification.Name("reloadStartViewController"), object: self)
        }
    }
    
//    func serialDidReceiveData(_ data: Data) {
//        let formattedData = data.hexEncodedString(options: .upperCase)
//        terminal.text = terminal.text.appending("[" + date.string(from: Date()) + "] temperature : " + formattedData + "\n")
//    }
    
    func serialDidReceiveBytes(_ bytes: [UInt8]) {
        // UInt8 Bytes [],[],[],[],[] 5개 read됨.
        // 그 중 1~4번째 인덱스에 있는 정보가 온도정보이므로 부동소수점 방식으로 온도 캘리브레이션
        let rawData = Array(bytes[1...4].reversed())
        var tempData: UInt32 = 0
        let data = NSData(bytes: rawData, length: 4)
        data.getBytes(&tempData, length: 4)
        tempData = UInt32(bigEndian: tempData)
        let mantissa = tempData & 0x00FFFFFF
        let exponent = -3   // 보류...
        let actualTemp = Double(mantissa) * pow(10, Double(exponent))
        terminal.text = terminal.text.appending("[" + date.string(from: Date()) + "] temperature : \(actualTemp)" + "\n")
    }
}

// HexaDecimal 형태로 보고 싶을 때
extension Data {
    struct HexEncodingOptions: OptionSet {
        let rawValue: Int8
        static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
}
    
    func hexEncodedString(options: HexEncodingOptions = []) -> String {
        let format = options.contains(.upperCase) ? "%02hhX" : "%02hhx"
        return map { String(format: format, $0)}.joined()
    }
}
