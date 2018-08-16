//
//  DeviceViewController.swift
//  BluetoothTest
//
//  Created by 임준오 on 2018. 8. 9..
//  Copyright © 2018년 Junoh. All rights reserved.
//

import UIKit
import CoreBluetooth

// 디바이스 컨트롤러
class DeviceViewController: UIViewController {

    // 스캔 커스텀 버튼
    @IBOutlet weak var scanButton: DeviceScanButton!
    @IBOutlet weak var tableView: UITableView!
    
    var peripherals: [(peripheral: CBPeripheral, RSSI: Float)] = []
    var selectedPeripheral: CBPeripheral?
    var progressHUD: MBProgressHUD? // alarm 역할을 할 라이브러리 내 객체 ( circle progress )
    var timer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        serial.delegate = self
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = 60
        if serial.centralManager.state != .poweredOn {
            print("블루투스가 꺼져있습니다.")
            return
        }
        scanButton.addTarget(self, action: #selector(startScan), for: .touchUpInside)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        serial.delegate = self
    }
    
    @objc func startScan() {
        peripherals = []
        tableView.reloadData()
        serial.startScan()
        print("start scan!")
        timer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(scanTimeOut), userInfo: nil, repeats: false)
    }
    
    @objc func scanTimeOut() {
        serial.stopScan()
        if let hud = progressHUD {
            hud.hide(false)
        }
        
        let hud = MBProgressHUD.showAdded(to: view, animated: true)
        hud?.mode = .text
        if peripherals.count == 0 {
            hud?.labelText = "Not found"
        } else {
            hud?.labelText = "Done scanning"
        }
        hud?.hide(true, afterDelay: 1)
    }
    
    @objc func connectTimeOut() {
        if let hud = progressHUD {
            hud.hide(false)
        }
        
        if let _ = selectedPeripheral {
            serial.disconnect()
            selectedPeripheral = nil
        }
        
        let hud = MBProgressHUD.showAdded(to: view, animated: true)
        hud?.mode = .text
        hud?.labelText = "Failed to connect"
        hud?.hide(true, afterDelay: 1)
    }
}

extension DeviceViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return peripherals.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let id = "cell"
        var cell = tableView.dequeueReusableCell(withIdentifier: id) as? DeviceCell
        
        if cell == nil {
            cell = DeviceCell(style: .default, reuseIdentifier: id)
        }
        
        cell?.name.text = peripherals[(indexPath as NSIndexPath).row].peripheral.name ?? "Unknown"
        cell?.uuid.text = "uuid : " + peripherals[(indexPath as NSIndexPath).row].peripheral.identifier.uuidString
        
        return cell!
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        // the user has selected a peripheral, so stop scanning and proceed to the next view
        serial.stopScan()
        selectedPeripheral = peripherals[(indexPath as NSIndexPath).row].peripheral
        serial.connectToPeripheral(selectedPeripheral!)
        progressHUD = MBProgressHUD.showAdded(to: view, animated: true)
        progressHUD?.labelText = "Connecting"
        
        timer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(connectTimeOut), userInfo: nil, repeats: false)
    }
}

extension DeviceViewController: BluetoothSerialDelegate {
    func serialDidDiscoverPeripheral(_ peripheral: CBPeripheral, RSSI: NSNumber?) {
        for existing in peripherals {
            if existing.peripheral.identifier == peripheral.identifier { return }
        }
        
        let theRSSI = RSSI?.floatValue ?? 0.0
        peripherals.append((peripheral: peripheral, RSSI: theRSSI))
        peripherals.sort{ $0.RSSI < $1.RSSI }
        tableView.reloadData()
    }
    
    func serialDidFailToConnect(_ peripheral: CBPeripheral, error: NSError?) {
        if let hud = progressHUD {
            hud.hide(false)
        }
        
        let hud = MBProgressHUD.showAdded(to: view, animated: true)
        hud?.mode = .text
        hud?.labelText = "Failed to connect"
        hud?.hide(true, afterDelay: 1.0)
    }
    
    func serialDidDisconnect(_ peripheral: CBPeripheral, error: NSError?) {
        if let hud = progressHUD {
            hud.hide(false)
        }
        
        let hud = MBProgressHUD.showAdded(to: view, animated: true)
        hud?.mode = .text
        hud?.labelText = "Failed to connect"
        hud?.hide(true, afterDelay: 1.0)
    }
    
    func serialIsReady(_ peripheral: CBPeripheral) {
        timer?.invalidate()
        if let hud = progressHUD {
            hud.mode = .customView
            hud.customView = UIImageView(image: UIImage(named: "check-mark"))
            hud.labelText = "connected to " + (peripheral.name ?? "unknown")
            hud.hide(true, afterDelay: 1.0)
        }
        
        NotificationCenter.default.post(name: Notification.Name(rawValue: "bluetoothStatusChanged"), object: self)
    }
    
    func serialDidChangeState() {
        timer?.invalidate()
        if let hud = progressHUD {
            hud.hide(false)
        }
        
        if serial.centralManager.state != .poweredOn {
            NotificationCenter.default.post(name: Notification.Name("bluetoothStatusChanged"), object: self)
        }
    }
}
