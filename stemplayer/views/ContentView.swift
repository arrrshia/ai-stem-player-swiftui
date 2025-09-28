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

    @State private var showingImporter = false
    @State private var selectedFolderID: StemFolder.ID? = nil
    @State private var selectedFileID: URL?

    // SoundCloud flow
    @State private var showingSoundcloudSheet = false
    @State private var scUrlText: String = ""
    @State private var isDownloading = false
    @State private var downloadError: String?

    private let API_BASE = URL(string: "YOURAPIHERE")!

    var body: some View {
        ZStack {
            Color(hex: 0xDAD6CD).ignoresSafeArea()

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
                    },
                    onSwipeFolder: { folder in
                        if selectedFolderID == folder.id { selectedFolderID = nil }
                        library.deleteStem(folder)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                )
                .frame(maxWidth: 520)
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .padding(.top, 8)

            // Top-right "+" as a dropdown menu
            VStack {
                HStack {
                    Spacer()
                    Menu {
                        Button {
                            showingImporter = true
                        } label: {
                            Label("Add File", systemImage: "doc.badge.plus")
                        }

                        Button {
                            scUrlText = ""
                            showingSoundcloudSheet = true
                        } label: {
                            Label("SoundCloud", systemImage: "waveform")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.7))
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(
                                Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 6)
                    }
                    .menuStyle(.automatic)
                    .buttonStyle(.plain)
                    .padding(.trailing, 16)
                    .padding(.top, 12)
                }
                Spacer()
            }
        }
        // Existing file importer flow
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let ogURL = urls.first {
                    library.splitTrack(ogURL)
                }
            case .failure(let error):
                print("File import error:", error.localizedDescription)
            }
        }
        .sheet(isPresented: $showingSoundcloudSheet) {
            SoundCloudSheetLite(
                scUrlText: $scUrlText,
                isWorking: $isDownloading,
                errorText: $downloadError,
                onSubmit: { url in
                    Task { await downloadFromSoundCloud(urlString: url) }
                },
                onCancel: { showingSoundcloudSheet = false }
            )
            .presentationDetents([.fraction(0.34)])          // single detent = no resize jump
            .presentationCornerRadius(24)
            .interactiveDismissDisabled(isDownloading)
            .presentationDragIndicator(.visible)
            .presentationBackground(.ultraThinMaterial)      // let system blur; avoid .clear jank
        }
        // Show a simple error alert if needed
        .alert("Download failed", isPresented: .constant(downloadError != nil), actions: {
            Button("OK") { downloadError = nil }
        }, message: {
            Text(downloadError ?? "Unknown error")
        })
    }

    // MARK: - Networking

    private func downloadFromSoundCloud(urlString: String) async {
        guard !isDownloading else { return }
        isDownloading = true
        downloadError = nil
        library.statusCurrent = "Fetching from SoundCloud…"

        defer {
            isDownloading = false
            library.statusCurrent = "Asleep"
        }

        guard let url = URL(string: urlString) else {
            downloadError = "Invalid URL"
            return
        }

        do {
            var req = URLRequest(url: API_BASE.appendingPathComponent("track"))
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let payload: [String: String] = ["url": url.absoluteString]
            req.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])

            let (data, resp) = try await URLSession.shared.data(for: req)
            let suggestedFilename: String
            if let http = resp as? HTTPURLResponse,
               let cd = http.value(forHTTPHeaderField: "Content-Disposition"),
               let range = cd.range(of: "filename=") {
                // Parse filename="xyz.mp3"
                let fn = cd[range.upperBound...].trimmingCharacters(in: .init(charactersIn: "\""))
                suggestedFilename = fn
            } else {
                // Fallback: take last path component from SoundCloud URL
                suggestedFilename = url.lastPathComponent + ".mp3"
            }

            let tmp = FileManager.default.temporaryDirectory
                .appendingPathComponent(suggestedFilename)

            try data.write(to: tmp, options: .atomic)
            // Hand off to your existing split flow
            await MainActor.run {
                library.statusCurrent = "Processing…"
                library.splitTrack(tmp)
                showingSoundcloudSheet = false
            }
        } catch {
            downloadError = error.localizedDescription
        }
    }
}

#Preview {
    ContentView()
}
