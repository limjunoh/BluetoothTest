//
//  GraphViewController.swift
//  BluetoothTest
//
//  Created by 임준오 on 2018. 8. 9..
//  Copyright © 2018년 Junoh. All rights reserved.
//

import UIKit
import Charts
import CoreBluetooth

// 그래프 컨트롤러
class GraphViewController: UIViewController {

    @IBOutlet weak var lineChartView: LineChartView!
    @IBOutlet weak var disconnectButton: UIButton!
    @IBOutlet weak var deviceName: UITextField!
    
    var Yvalue = (0..<100).map{(i)-> Double in
        return Double(0)
    }
    var isConnected: Bool = false {
        didSet {
            if isConnected == true {
                disconnectButton.isEnabled = true
            } else {
                disconnectButton.isEnabled = false
                deviceName.text = "----"
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        serial = BluetoothSerial(delegate: self)
        deviceName.isUserInteractionEnabled = false
        disconnectButton.isEnabled = false
        
        NotificationCenter.default.addObserver(self, selector: #selector(reloadView), name: NSNotification.Name(rawValue: "bluetoothStatusChanged"), object: nil)
        
        initChart()
        // Do any additional setup after loading the view.
    }
    
    
    
    @objc func reloadView() {
        serial.delegate = self
        
        if serial.isReady { // 연결 시
            let device = serial.connectedPeripheral?.name ?? "Unknown"
            deviceName.text = device
            isConnected = true
        } else {            // 연결 끊김
            isConnected = false
        }
    }
    
    func initChart(){
        var lineChartEntry = [ChartDataEntry]()
        
        for i in 0..<Yvalue.count{
            let value = ChartDataEntry(x: Double(i), y: 0)
            lineChartEntry.append(value)
        }
        let set = getChartSet(values: lineChartEntry, label: "Cel")
        let data = LineChartData()
        data.addDataSet(set)
        
        lineChartView.data = data
        
        lineChartView.chartDescription?.text = "Temperature"
    }
    func updateChart(yData:Double) {
        var lineChartEntry = [ChartDataEntry]()
        
        Yvalue.removeFirst()
        Yvalue.append(yData)
        
        for i in 0..<Yvalue.count{
            let value = ChartDataEntry(x: Double(i), y: Yvalue[i])
            lineChartEntry.append(value)
        }
        let set = getChartSet(values: lineChartEntry, label: "Cel")
        let data = LineChartData()
        data.addDataSet(set)
        lineChartView.data = data
        
        lineChartView.chartDescription?.text = "Temperature"
    }
    
    func getChartSet(values:[ChartDataEntry], label:String) -> LineRadarChartDataSet {
        let set = LineChartDataSet(values: values, label: "Number")
        set.colors = [NSUIColor.blue]
        set.mode = .cubicBezier
        set.lineWidth = 1.0
        set.circleRadius = 0.0
        set.drawHorizontalHighlightIndicatorEnabled = false
        
        return set
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func clearAction(_ sender: UIButton) {
        serial.disconnect()
        Yvalue = (0..<100).map{(i)-> Double in
            return Double(0)
        }
    }

    @IBAction func disconnectAction(_ sender: UIButton) {
        serial.disconnect()
    }
    
    

}
extension GraphViewController:BluetoothSerialDelegate{
    func serialDidFailToConnect(_ peripheral: CBPeripheral, error: NSError?) {
        print("블루투스 연결 실패")
    }
    
    func serialDidDisconnect(_ peripheral: CBPeripheral, error: NSError?) {
        print("블루투스 연결이 끊어졌습니다")
    }
    //??--
    func serialIsReady(_ peripheral: CBPeripheral) {
        NotificationCenter.default.post(name: Notification.Name(rawValue: "reloadStartViewController"), object: self)
    }
    
    func serialDidChangeState() {
        if serial.centralManager.state != .poweredOn {
            NotificationCenter.default.post(name: Notification.Name("reloadStartViewController"), object: self)
        }
    }
    //--??
    
    func serialDidReceiveBytes(_ bytes: [UInt8]) {
        // UInt8 Bytes [],[],[],[],[] 5개 read됨.
        // 그 중 1~4번째 인덱스에 있는 정보가 온도정보이므로 부동소수점 방식으로 온도 캘리브레이션
        let rawData = Array(bytes[1...4].reversed())
        var tempData: UInt32 = 0
        let data = NSData(bytes: rawData, length: 4)
        data.getBytes(&tempData, length: 4)
        tempData = UInt32(bigEndian: tempData)
        let mantissa = tempData & 0x00FFFFFF
        let exponent = -1   // 보류...
        let actualTemp = Double(mantissa) * pow(10, Double(exponent))
        
        Yvalue.removeFirst()
        Yvalue.append(actualTemp)
    }
}
