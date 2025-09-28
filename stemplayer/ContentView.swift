//
//  ContentView.swift
//  stemplayer
//
//  Created by Andrew Arshia Almasi on 9/20/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var engine = StemEngine()
    @StateObject private var library = StemLibrary()
    
    @State private var showingFolderImporter = false
    @State private var showingImporter = false
    @State private var importedURLs: [URL] = []
    
    // Track which folder is currently loaded
    @State private var selectedFolderID: StemFolder.ID? = nil
    @State private var selectedFileID: URL?
    var body: some View {
        ZStack {
            Color(hex: 0xDAD6CD).ignoresSafeArea()
            
            // Main layout: center player vertically, list below (smaller)
            VStack(spacing: 16) {
                Spacer(minLength: 0)
                
                StemPlayer(
                    levels: $engine.levels,
                    isPlaying: engine.isPlaying,
                    playPause: { engine.isPlaying ? engine.pause() : engine.play() }
                )
                .frame(maxWidth: 520)
                .padding(.horizontal)
                .opacity(engine.isLoaded ? 1 : 0.95)
                if !library.statusCurrent.isEmpty,
                   library.statusCurrent.lowercased() != "asleep" {
                    LoadingLabel(text: library.statusCurrent)
                        .transition(.opacity.combined(with: .scale))
                        .padding(.top, 4)
                }

                Spacer(minLength: 40)
                
                GlassFolderList(
                    library: library,
                    selectedFolderID: selectedFolderID,
                    onTapFolder: { folder in
                        engine.load(folder: folder)
                        selectedFolderID = folder.id
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    },
                    onPressLoad: { folder in
                        engine.load(folder: folder)
                        selectedFolderID = folder.id
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                )
                .frame(maxWidth: 520)
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .padding(.top, 8)
            
            // Top-right glass "+" button for folder import
            VStack {
                HStack {
                    Spacer()
                    Button {
                        showingFolderImporter = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.7))
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 6)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 16)
                    .padding(.top, 12)
                }
                Spacer()
            }
        }
        .fileImporter(
            isPresented: $showingFolderImporter,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let ogURL = urls.first {
                    library.splitTrack(ogURL)
                }
            case .failure(let error):
                print("Error", error.localizedDescription)
            }
        }
    }
}
private struct Shimmer: ViewModifier {
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
private struct LoadingLabel: View {
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

// MARK: - Glass List

private struct GlassFolderList: View {
    let library: StemLibrary
    let selectedFolderID: StemFolder.ID?
    var onTapFolder: (StemFolder) -> Void       // tap anywhere on row (name area)
    var onPressLoad: (StemFolder) -> Void       // press the "Load" button

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "music.note.list")
                    .foregroundStyle(.secondary)
                Text("Local Stem Folders")
                    .font(.headline)
                    .foregroundStyle(.primary.opacity(0.9))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)

            if library.folders.isEmpty {
                Text("Add a folder that contains 4 audio files (one per stem).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(library.folders) { folder in
                            let isSelected = folder.id == selectedFolderID

                            HStack(spacing: 12) {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "square.stack.3d.up")
                                    .foregroundStyle(isSelected ? Color.green.opacity(0.9) : .secondary)
                                    .symbolRenderingMode(.palette)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(folder.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text(folder.stemNames.joined(separator: " • "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                if isSelected {
                                    Text("Loaded")
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 10).padding(.vertical, 6)
                                        .background(
                                            Capsule().fill(Color.green.opacity(0.18))
                                        )
                                        .overlay(
                                            Capsule().stroke(Color.green.opacity(0.35), lineWidth: 1)
                                        )
                                        .foregroundStyle(Color.green.opacity(0.9))
                                        .transition(.opacity.combined(with: .scale))
                                } else {
                                    Button {
                                        onPressLoad(folder)
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "arrow.down.circle")
                                            Text("Load")
                                                .font(.caption.weight(.semibold))
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(.ultraThinMaterial, in: Capsule())
                                        .overlay(
                                            Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1)
                                        )
                                        .foregroundStyle(.primary)
                                    }
                                    .buttonStyle(PressableStyle())
                                    .transition(.opacity.combined(with: .scale))
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                // row glass card w/ selected accent
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(isSelected ? Color.green.opacity(0.35) : Color.white.opacity(0.18), lineWidth: 1)
                                    )
                                    .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onTapFolder(folder)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
                .frame(maxHeight: 160)
                .scrollIndicators(.hidden)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)
        )
        .animation(.spring(response: 0.28, dampingFraction: 0.88, blendDuration: 0.15), value: selectedFolderID)
    }
}


#Preview {
    ContentView()
}

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

