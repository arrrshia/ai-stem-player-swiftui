//
//  StemPlayer.swift
//  stemplayer
//
//  Created by Andrew Arshia Almasi on 9/27/25.
//

import SwiftUI

struct StemPlayer: View {
    @Binding var levels: [Int]       // [right, top, left, bottom]
    var isPlaying: Bool
    var playPause: () -> Void
    
    // theme
    private let player = Color(hex: 0x9c836a)
    private let playerBorder = Color(hex: 0x856849)
    private let slotTint = Color(hex: 0x997b5c).opacity(0.55) // softer, translucent slot
    private let lightOff = Color(hex: 0x8a7159)
    @State private var dragStartLevel: [Int: Int] = [:] // per-slider starting level
    
    // lights (replace with your palette)
    private let lightColors: [Color] = [
        Color(red: 0.95, green: 0.20, blue: 0.10), // red
        Color(red: 0.70, green: 0.25, blue: 0.60), // magenta
        Color(red: 0.45, green: 0.30, blue: 0.75), // purple
        Color(red: 0.26, green: 0.31, blue: 0.89)  // blue
    ]
    
    var body: some View {
        GeometryReader { geo in
            let D = min(geo.size.width, geo.size.height)   // disk diameter
            let R = D / 2
            let slotW = D * 0.36
            let slotH = D * 0.17
            let slotR = slotH / 2
            let lightsSize = slotH * 0.34
            let lightsGap  = slotH * 0.10
            let offsetR = R * 0.58  // distance of slot center from disk center
            
            ZStack {
                // --- Ambient halo + base shadow, very soft ---
                Circle()
                    .fill(Color.black.opacity(0.22))
                    .frame(width: D * 1.08, height: D * 1.08)
                    .blur(radius: D * 0.20)
                    .offset(y: D * 0.06)
                
                // --- Disk ---
                Circle()
                    .fill(player)
                    .overlay(Circle().stroke(playerBorder, lineWidth: 1))
                // subtle bevel (top-left highlight, bottom-right shade)
                    .innerShadow(color: .white.opacity(0.25), radius: D * 0.065, offset: .init(width: -D*0.02, height: -D*0.03))
                    .innerShadow(color: .black.opacity(0.28), radius: D * 0.085, offset: .init(width: D*0.03, height: D*0.05))
                // a faint overall softness
                    .shadow(color: .black.opacity(0.10), radius: D*0.10, x: 0, y: D*0.02)
                
                // --- Slots (recessed) ---
                slot(width: slotW, height: slotH, corner: slotR, index: 1, lightsSize: lightsSize, lightsGap: lightsGap) // top
                    .rotationEffect(.degrees(-90))
                    .offset(y: -offsetR)
                
                slot(width: slotW, height: slotH, corner: slotR, index: 3, lightsSize: lightsSize, lightsGap: lightsGap) // bottom
                    .rotationEffect(.degrees(90))
                    .offset(y:  offsetR)
                
                slot(width: slotW, height: slotH, corner: slotR, index: 2, lightsSize: lightsSize, lightsGap: lightsGap) // left
                    .rotationEffect(.degrees(180))
                    .offset(x: -offsetR)
                
                slot(width: slotW, height: slotH, corner: slotR, index: 0, lightsSize: lightsSize, lightsGap: lightsGap) // right
                    .offset(x:  offsetR)
                
                // --- Center play button (slightly raised “pill”) ---
                Button(action: playPause) {
                    Circle()
                        .fill(player)
                        .overlay(Circle().stroke(playerBorder, lineWidth: 1))
                    // outer soft lift
                        .shadow(color: .white.opacity(0.35), radius: D*0.015, x: -D*0.01, y: -D*0.01)
                        .shadow(color: .black.opacity(0.25), radius: D*0.025, x: D*0.02, y: D*0.03)
                    // subtle inner ring to keep it grounded
                        .overlay(
                            Circle()
                                .stroke(LinearGradient(colors: [
                                    .white.opacity(0.25),
                                    .black.opacity(0.20)
                                ], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: D*0.010)
                                .blur(radius: D*0.004)
                                .opacity(0.7)
                        )
                }
                .frame(width: D * 0.18, height: D * 0.18)
            }
            .frame(width: D, height: D)
            .position(x: geo.size.width/2, y: geo.size.height/2)
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(18)
    }
    
    // MARK: - Slot (recessed capsule)
    private func slot(width: CGFloat,
                      height: CGFloat,
                      corner: CGFloat,
                      index: Int,
                      lightsSize: CGFloat,
                      lightsGap: CGFloat) -> some View {

        // derive step size from slot height (bigger slot -> bigger drag needed)
        let stepSize = height * 0.75   // try 0.6–1.0; larger = less sensitive
        
        let rim = height * 0.10
        let blur = height * 0.04
        let hair = max(1, height * 0.012)

        return RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(player)
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(playerBorder, lineWidth: 1)
            )
            // concave look
            .innerShadow(color: .white.opacity(0.35), radius: height*0.8, offset: .init(width: -height * 0.20, height: -height*0.22))
            .innerShadow(color: .black.opacity(0.30), radius: height*0.8, offset: .init(width: height * 0.20, height: height*0.22))
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(
                        LinearGradient(colors: [
                            .black.opacity(0.22),
                            .white.opacity(0.24)
                        ], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: rim
                    )
                    .blur(radius: blur)
                    .opacity(0.70)
            )
        // delicate inner hairline to “seat” the slot (keeps it from floating)
        .overlay(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .inset(by: hair)
                .stroke(
                    LinearGradient(colors: [
                        .white.opacity(0.15),
                        .black.opacity(0.18)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: hair
                )
                .blendMode(.overlay)
                .opacity(0.9)
        )

        .frame(width: width, height: height)
        .overlay(
            HStack(spacing: lightsGap) {
                ForEach(0..<4, id: \.self) { i in
                    let isOn = (i < levels[index])
                    SolidGlowLED(color: lightColors[i], size: lightsSize, isOn: isOn, intensity: 1.0)
                }
            }
                .padding(.vertical, height * 0.12)
                .padding(.horizontal, lightsSize * 0.20) // small breathing room
                .compositingGroup()
                .mask(
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .inset(by: -height * 0.18) // negative = larger than the slot
                )
            .allowsHitTesting(false)
        )

            // ensure the rounded capsule is the hit region
            .contentShape(RoundedRectangle(cornerRadius: corner, style: .continuous))

            // attach your gesture with tuned stepSize
            .gesture(dragGesture(index: index, stepSize: stepSize), including: .all)
    }

    
    private func dragGesture(index: Int,
                             stepSize: CGFloat = 50) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // capture the starting level once
                if dragStartLevel[index] == nil {
                    dragStartLevel[index] = levels[index]
                }
                let start = dragStartLevel[index] ?? levels[index]
                let local = CGVector(dx: value.translation.width,
                                     dy: value.translation.height)
                let t = correctedTranslation(local, for: index)
                let centerPull = vectorTowardCenter(for: index)
                let dot = t.dx * centerPull.dx + t.dy * centerPull.dy

                // 3) Convert to steps and clamp 0...4 (allow fully off)
                let steps = Int((dot / stepSize).rounded(.toNearestOrAwayFromZero))
                let newLevel = max(0, min(4, start - steps))

                if newLevel != levels[index] {
                    levels[index] = newLevel
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
            .onEnded { _ in
                dragStartLevel[index] = nil
            }
    }

    private func vectorTowardCenter(for index: Int) -> CGVector {
        switch index {
        case 0: return CGVector(dx: -1, dy: 0)   // right slot -> center to the left
        case 1: return CGVector(dx: 0, dy: -1)    // top slot -> center is downward
        case 2: return CGVector(dx: 1, dy: 0)    // left slot -> center to the right
        case 3: return CGVector(dx: 0, dy: 1)   // bottom slot -> center upward
        default: return .zero
        }
    }
    private func rotationDegrees(for index: Int) -> Double {
        switch index {
        case 0: return 0      // right
        case 1: return -90    // top
        case 2: return 180    // left
        case 3: return 90     // bottom
        default: return 0
        }
    }

    private func correctedTranslation(_ t: CGVector, for index: Int) -> CGVector {
        // The view is rotated by θ; the DragGesture translation is in that rotated space.
        // Rotate the vector by -θ to bring it back to global/screen axes.
        let theta = rotationDegrees(for: index) * .pi / 180.0
        let c = cos(theta)
        let s = sin(theta)
        let dx = t.dx * c + t.dy * s
        let dy = -t.dx * s + t.dy * c
        return CGVector(dx: dx, dy: dy)
    }

}
