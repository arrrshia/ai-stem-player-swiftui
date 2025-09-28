//
//  PressableStyle.swift
//  stemplayer
//
//  Created by Andrew Arshia Almasi on 9/27/25.
//

import SwiftUI

// MARK: - Button Style (Press Down)

struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    var pressedOpacity: Double = 0.75

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? pressedOpacity : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.85), value: configuration.isPressed)
    }
}
