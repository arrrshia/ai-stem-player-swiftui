//
//  Color+Hex.swift
//  stemplayer
//
//  Created by Andrew Arshia Almasi on 9/28/25.
//

import Foundation
import SwiftUI

extension Color {
    init(red: Int, green: Int, blue: Int) {
       assert(red >= 0 && red <= 255, "Invalid red component")
       assert(green >= 0 && green <= 255, "Invalid green component")
       assert(blue >= 0 && blue <= 255, "Invalid blue component")

       self.init(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0)
   }

    init(hex: UInt32, alpha: Double = 1.0) {
            let r = Double((hex >> 16) & 0xFF) / 255.0
            let g = Double((hex >> 8) & 0xFF) / 255.0
            let b = Double(hex & 0xFF) / 255.0
            self = Color(.sRGB, red: r, green: g, blue: b, opacity: alpha)
   }
}
