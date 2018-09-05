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
import Firebase

// 그래프 컨트롤러
class GraphViewController: UIViewController {

    @IBOutlet weak var lineChartView: LineChartView!
    @IBOutlet weak var disconnectButton: UIButton!
    @IBOutlet weak var deviceName: UITextField!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var fileNameTextField: UITextField!
    
    let UPLOAD_VALUE_NUMBER = 100
    //line chart의 y value array
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
    //저장 확인 변수
    var isSaving:Bool = false{
        didSet{
            if isSaving == true{
                saveButton.setTitle("Stop", for: .normal)
            }else{
                saveButton.setTitle("Save", for: .normal)
                countValues = 0
            }
        }
    }
    var buffer:[Double] = []
    var countValues:Int = 0
    var ref: DatabaseReference!
    var valueRef: DatabaseReference!
    let date = DateFormatter()
    let timeToStartSaving = DateFormatter()
    var count:UInt = 0
    var deviceServiceUUID:CBUUID!
    var bluetoothUUID = BluetoothUUID()
    var filename = "unknown"
    var valueType:String?{
        didSet{
            if valueType == nil{
                valueType = "unknown"
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        serial = BluetoothSerial(delegate: self)
        deviceName.isUserInteractionEnabled = false
        disconnectButton.isEnabled = false
        
        NotificationCenter.default.addObserver(self, selector: #selector(reloadView), name: NSNotification.Name(rawValue: "bluetoothStatusChanged"), object: nil)
        //기본 chart 생성
        initChart()
        //firebase reference 생성
        ref = Database.database().reference()
        
        date.locale = Locale(identifier: "ko_kr")
        date.timeZone = TimeZone(abbreviation: "KST")
        date.dateFormat = "yyyy-MM-dd"
        timeToStartSaving.locale = Locale(identifier: "ko_kr")
        timeToStartSaving.timeZone = TimeZone(abbreviation: "KST")
        timeToStartSaving.dateFormat = "yyyy-MM-dd HH:mm:ss"
    }
    
    override func viewDidAppear(_ animated: Bool) {
        serial.delegate = self
    }
    deinit {
        NotificationCenter.default.removeObserver(self)
        // 옵저버 제거
    }
    
    @objc func reloadView() {
        serial.delegate = self
        if serial.isReady { // 연결 시
            let device = serial.connectedPeripheral?.name ?? "Unknown"
            deviceName.text = device
            isConnected = true
            //연결시 service uuid 저장
            for temp in (serial.connectedPeripheral?.services)!{
                deviceServiceUUID = temp.uuid
            }
            
        } else {            // 연결 끊김
            isConnected = false
        }
    }
    
    func initChart(){
        var lineChartEntry = [ChartDataEntry]() //charts에서 쓰는 자료형
        
        for i in 0..<Yvalue.count{
            let value = ChartDataEntry(x: Double(i), y: 0) //entry x,y 설정
            lineChartEntry.append(value)
        }
        
        let set = getChartSet(values: lineChartEntry, label: "value")
        let data = LineChartData()
        data.addDataSet(set)
        
        lineChartView.data = data
        
        lineChartView.chartDescription?.text = "Graph"
    }
    //chart 업데이트
    func updateChart(yData:Double) {
        var lineChartEntry = [ChartDataEntry]()
        
        Yvalue.removeFirst()
        Yvalue.append(yData)
        
        for i in 0..<Yvalue.count{
            let value = ChartDataEntry(x: Double(i), y: Yvalue[i])
            lineChartEntry.append(value)
        }
        let set = getChartSet(values: lineChartEntry, label: "value")
        let data = LineChartData()
        data.addDataSet(set)
        lineChartView.data = data
        
        lineChartView.chartDescription?.text = "Graph"
    }
    
    //chart 셋팅
    func getChartSet(values:[ChartDataEntry], label:String) -> LineRadarChartDataSet {
        let set = LineChartDataSet(values: values, label: label)
        set.colors = [NSUIColor.blue]
        set.mode = .cubicBezier
        set.lineWidth = 1.0
        set.circleRadius = 0.0
        set.drawHorizontalHighlightIndicatorEnabled = false
        return set
    }
    
    func valuesToString(buffer:[Double]) -> String {
        var temp = ""
        for value in buffer{
            temp += String(value)
            temp += ","
        }
        temp.removeLast()
        return temp
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func clearAction(_ sender: UIButton) {
        Yvalue = (0..<100).map{(i)-> Double in
            return Double(0)
        }
        updateChart(yData: 0.0)
    }

    @IBAction func disconnectAction(_ sender: UIButton) {
        serial.disconnect()
        isConnected = false
    }
    

    @IBAction func saveAction(_ sender: UIButton) {
        if isConnected{
            if isSaving{
                isSaving = false
            }else{
                countValues = 0
                buffer = []
                count = 0
                isSaving = true
                
                //database 저장 시 이름 받아서 올림.
                if self.fileNameTextField.text != nil{
                    filename = self.fileNameTextField.text!
                }else{
                    filename = "unknown"
                }
                filename += "_" + timeToStartSaving.string(from: Date())
                //종류에 따라 key 이름 정해줌
                valueType = bluetoothUUID.valueType[deviceServiceUUID]
                
                self.ref.child("Sensor").child(filename).setValue(["Date":timeToStartSaving.string(from: Date())])
                self.ref.child("Sensor/\(filename)").child("value")
                valueRef = Database.database().reference().child("Sensor/\(filename)/value")
            }
        }else{
            let hud = MBProgressHUD.showAdded(to: view, animated: true)
            hud?.mode = .text
            hud?.labelText = "Device is not connected"
            hud?.hide(true, afterDelay: 1)
        }
        
        
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.fileNameTextField.endEditing(true)
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
    
    func serialDidReceiveBytes(_ bytes: [UInt8]) {
//        print("LOG:serialDidReceiveBytes = \(bytes)")
        var convertedData:Double = 0.0
        //service uuid에 따라 데이터 변환 분류
        switch deviceServiceUUID {
            case bluetoothUUID.HM10_Service_CBUUID:
                let temp = String(bytes: bytes, encoding: .utf8)
                convertedData = temp!.doubleValue
            
            case bluetoothUUID.BLE_Temperature_Service_CBUUID:
                // UInt8 Bytes [],[],[],[],[] 5개 read됨.
                // 그 중 1~4번째 인덱스에 있는 정보가 온도정보이므로 부동소수점 방식으로 온도 캘리브레이션
                let rawData = Array(bytes[1...4].reversed())
                var tempData: UInt32 = 0
                let data = NSData(bytes: rawData, length: 4)
                data.getBytes(&tempData, length: 4)
                tempData = UInt32(bigEndian: tempData)
                let mantissa = tempData & 0x00FFFFFF
                let exponent = -3  // 보류...
                convertedData = Double(mantissa) * pow(10, Double(exponent))
                print(mantissa, exponent)
            
            default:
                print("ERROR: Service UUID is not correct.")
        }


        
        updateChart(yData: convertedData)
        if isSaving{
            buffer.append(convertedData)
            countValues += 1
            
            print("LOG: buffer.count = \(buffer.count) ")
            print("LOG: countValues = \(countValues) ")
        }
        
        if countValues == UPLOAD_VALUE_NUMBER {
            //db업로드 백그라운드 쓰레드
            DispatchQueue.global(qos: .background).async {
                DispatchQueue.main.async {
                    let temp = self.valuesToString(buffer: self.buffer)
                    self.valueRef.observeSingleEvent(of: .value) { (snapshot) in
                        self.count = snapshot.childrenCount
                    }
                    self.ref.child("Sensor/\(self.filename)/value").child(String(self.count)).setValue([self.valueType!:temp])
                    self.countValues = 0
                    self.buffer = []
                }
            }
        }
        
        
    }
}

extension String {
    var doubleValue: Double {
        return (self as NSString).doubleValue
    }
}





