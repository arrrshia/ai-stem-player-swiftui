//
//  LoadingLabel.swift
//  stemplayer
//
//  Created by Andrew Arshia Almasi on 9/28/25.
//

import Foundation
import SwiftUI

struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = -1.0
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [.white.opacity(0.0), .white.opacity(0.45), .white.opacity(0.0)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .rotationEffect(.degrees(15))
                .offset(x: phase * 160, y: 0)
                .blendMode(.screen)
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 1.0
                }
            }
    }
}
struct LoadingLabel: View {
    let text: String
    @State private var tick = 0
    private var dots: String { String(repeating: ".", count: (tick % 3) + 1) }
    
    var body: some View {
        Text("\(text)\(dots)")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.black.opacity(0.85), Color.black.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule().stroke(Color.white.opacity(0.28), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.10), radius: 10, x: 0, y: 6)
            .modifier(Shimmer())
            .onReceive(Timer.publish(every: 0.45, on: .main, in: .common).autoconnect()) { _ in
                tick += 1
            }
    }
}
