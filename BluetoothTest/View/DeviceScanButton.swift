//
//  DeviceScanButton.swift
//  BluetoothTest
//
//  Created by 임준오 on 2018. 8. 14..
//  Copyright © 2018년 Junoh. All rights reserved.
//

import UIKit

// 스캔 커스텀 버튼
@IBDesignable
public class DeviceScanButton: UIButton {

    // 버튼 이미지
    @IBInspectable
    public var image: UIImage? = UIImage(named: "Device") {
        didSet {
            self.setImage(image, for: .normal)
        }
    }
    
    // 누를때 색깔 회색으로 바뀜
    override open var isHighlighted: Bool {
        didSet {
            backgroundColor = isHighlighted ? UIColor.gray : UIColor.blue
        }
    }
    
    // 코드 생성자
    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.setup()
    }
    
    // 스토리보드 생성자
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setup()
    }
    
    // 배경 원형으로 변경
    private func setup() {
        self.layer.cornerRadius = self.frame.size.width / 2
        self.clipsToBounds = true
        self.layer.borderWidth = 0.5
        self.layer.borderColor = UIColor.lightGray.cgColor
        self.backgroundColor = UIColor.blue
    }
    
}
