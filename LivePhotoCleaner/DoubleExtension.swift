//
//  DoubleExtension.swift
//  LivePhotosCleanUp
//
//  Created by Marco Schillinger on 18.01.21.
//

import Foundation

extension Double {
    func roundToDecimal(_ fractionDigits: Int) -> Double {
        let multiplier = pow(10, Double(fractionDigits))
        return Darwin.round(self * multiplier) / multiplier
    }
}
