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
import CoreData
import Firebase

// 그래프 컨트롤러
class GraphViewController: UIViewController {

    let UPLOAD_VALUE_NUMBER = 100
    
    @IBOutlet weak var lineChartView: LineChartView!
    @IBOutlet weak var disconnectButton: UIButton!
    @IBOutlet weak var deviceName: UITextField!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var fileNameTextField: UITextField!
    
    var currentThermometerObject: ThermometerMO?
    
    lazy var list: [ValueMO]? = {
        return self.currentThermometerObject?.values?.array as? [ValueMO]
    }()
    
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
            }
        }
    }
    
    var ref: DatabaseReference!
    var valueRef: DatabaseReference!
    let date = DateFormatter()
    let timeToStartSaving = DateFormatter()
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
    
    func thermometerSave(fileName: String, deviceName: String, date: String) -> ThermometerMO? {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let context = appDelegate.persistentContainer.viewContext
        
        let object = NSEntityDescription.insertNewObject(forEntityName: "Thermometer", into: context) as! ThermometerMO
        object.filename = fileName
        object.date = date
        object.devicename = deviceName

        do {
            try context.save()
            return object
        } catch {
            context.rollback()
            return nil
        }
    }
    
    func valueSave(regDate: Date, value: Double) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let context = appDelegate.persistentContainer.viewContext
        let valueObject = NSEntityDescription.insertNewObject(forEntityName: "Values", into: context) as! ValueMO
        valueObject.regdate = regDate
        valueObject.value = value
        currentThermometerObject?.addToValues(valueObject)
        
        do {
            try context.save()
            list?.append(valueObject)
        } catch {
            context.rollback()
        }
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
            // Saving 종료 시, 로컬 DB에 있는 값들 Firebase DB로 업로드
            if isSaving{
                DispatchQueue.global(qos: .background).async {
                    // background 작업 수행
                    guard let list = self.list else {
                        return
                    }
                    var buffer: [Double] = []
                    var count = 0
                    for object in list {
                        let value = object.value
                        buffer.append(value)
                        if buffer.count == self.UPLOAD_VALUE_NUMBER {
                            let temp = self.valuesToString(buffer: buffer)
                            self.ref.child("Sensor/\(self.filename)/value").child(String(count)).setValue([self.valueType!:temp])
                            buffer = []
                            count += 1
                        }
                    }
                    
                    // UI 부분 Main Queue로 돌아감.
                    DispatchQueue.main.async {
                        // UI 단에서 해야 할 처리.. (ex : 데이터베이스 업로드 완료 메시지 또는 푸쉬 알람 띄우기)
                    }
                }
                isSaving = false
            } else {
                isSaving = true
                
                let saveStartTime = timeToStartSaving.string(from: Date())
                //database 저장 시 이름 받아서 올림.
                if self.fileNameTextField.text != nil{
                    filename = self.fileNameTextField.text!
                } else {
                    filename = "unknown"
                }
                filename += "_" + saveStartTime
                
                // 로컬 DB에 metadata 저장
                currentThermometerObject = thermometerSave(fileName: filename, deviceName: self.deviceName.text ?? "unknown", date: saveStartTime)
                
                //종류에 따라 key 이름 정해줌 ( Firebase DB 에 metadata 저장 )
                valueType = bluetoothUUID.valueType[deviceServiceUUID]
                let info = NSDictionary(dictionary: ["DeviceName":self.deviceName.text ?? "unknown", "Date":saveStartTime])
                self.ref.child("Sensor").child(filename).setValue(info)
                self.ref.child("Sensor/\(filename)").child("value")
                valueRef = Database.database().reference().child("Sensor/\(filename)/value")
            }
        } else {
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
    
    func serialIsReady(_ peripheral: CBPeripheral) {
        NotificationCenter.default.post(name: Notification.Name(rawValue: "reloadStartViewController"), object: self)
    }
    
    func serialDidChangeState() {
        if serial.centralManager.state != .poweredOn {
            NotificationCenter.default.post(name: Notification.Name("reloadStartViewController"), object: self)
        }
    }

    func serialDidDiscoverPeripheral(_ peripheral: CBPeripheral, RSSI: NSNumber?) {}
    
    func serialDidReceiveBytes(_ bytes: [UInt8]) {
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
                let exponent = -1  // 보류...
                convertedData = Double(mantissa) * pow(10, Double(exponent))
            
            default:
                print("ERROR: Service UUID is not correct.")
        }
        updateChart(yData: convertedData)
        
        if isSaving, self.list != nil {
            valueSave(regDate: Date(), value: convertedData)
        }
    }
}

extension String {
    var doubleValue: Double {
        return (self as NSString).doubleValue
    }
}





