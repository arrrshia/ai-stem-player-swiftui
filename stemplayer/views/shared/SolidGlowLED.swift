//
//  SolidGlowLED.swift
//  stemplayer
//
//  Created by Andrew Arshia Almasi on 9/28/25.
//

import SwiftUI

struct SolidGlowLED: View {
    var color: Color
    var size: CGFloat
    var isOn: Bool
    /// 0.0–1.0 (overall glow strength)
    var intensity: CGFloat = 1.0

    var body: some View {
        let s = size
        let r1 = s * (0.75 * intensity)   // outer blur
        let r2 = s * (0.40 * intensity)   // inner blur

        ZStack {
            if isOn {
                // two soft blooms to get that “fuzzy” LED halo
                Circle()
                    .fill(color)
                    .frame(width: s, height: s)
                    .blur(radius: r1)
                    .opacity(0.70)
                    .blendMode(.screen)

                Circle()
                    .fill(color)
                    .frame(width: s, height: s)
                    .blur(radius: r2)
                    .opacity(0.55)
                    .blendMode(.screen)
            }

            // solid core
            Circle()
                .fill(isOn ? color : color.opacity(0.35))
                .frame(width: s, height: s)
        }
        .frame(width: s, height: s)
        .compositingGroup()
        .allowsHitTesting(false)
    }
}
