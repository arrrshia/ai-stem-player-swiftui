//
//  View+InnerShadow.swift
//  stemplayer
//
//  Created by Andrew Arshia Almasi on 9/28/25.
//

import SwiftUI

struct InnerShadow: ViewModifier {
    var color: Color
    var radius: CGFloat
    var offset: CGSize

    func body(content: Content) -> some View {
        content
            .overlay(
                content
                    .mask(
                        content
                            .offset(offset)
                            .blur(radius: radius)
                    )
                    .foregroundColor(color)
                    .blendMode(.multiply)
            )
    }
}

extension View {
    func innerShadow(color: Color, radius: CGFloat, offset: CGSize) -> some View {
        modifier(InnerShadow(color: color, radius: radius, offset: offset))
    }
}
