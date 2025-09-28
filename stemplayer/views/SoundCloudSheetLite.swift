//
//  SoundCloudSheetLite.swift
//  stemplayer
//
//  Created by Andrew Arshia Almasi on 9/28/25.
//

import Foundation
import SwiftUI
// MARK: - SoundCloudSheetLite (fast + clean)

struct SoundCloudSheetLite: View {
    @Binding var scUrlText: String
    @Binding var isWorking: Bool
    @Binding var errorText: String?

    var onSubmit: (String) -> Void
    var onCancel: () -> Void

    @FocusState private var fieldFocused: Bool

    private var isValidURL: Bool {
        let t = scUrlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: t),
              ["http","https"].contains(url.scheme?.lowercased())
        else { return false }
        return (url.host?.lowercased().contains("soundcloud.com") ?? false) ||
               (url.host?.lowercased().contains("sndcdn.com") ?? false)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Header
            HStack(spacing: 12) {
                Image(systemName: "waveform")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background(.thinMaterial, in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Import from SoundCloud")
                        .font(.headline)
                    Text("Paste a track or playlist URL")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(.thinMaterial, in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(isWorking)
                .opacity(isWorking ? 0.6 : 1)
            }

            // URL field
            HStack(spacing: 10) {
                Image(systemName: "link")
                    .foregroundStyle(.secondary)

                TextField("Paste SoundCloud URL", text: $scUrlText)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .keyboardType(.URL)
                    .submitLabel(.go)
                    .focused($fieldFocused)
                    .onSubmit { submitIfPossible() }

                Button {
                    if let s = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !s.isEmpty {
                        scUrlText = s
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                } label: {
                    Text("Paste")
                        .font(.callout.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(isWorking)
                .opacity(isWorking ? 0.6 : 1)
            }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            )

            if let err = errorText, !err.isEmpty {
                Text(err)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .transition(.opacity)
            }

            // CTA
            Button(action: submitIfPossible) {
                HStack(spacing: 10) {
                    if isWorking {
                        ProgressView().progressViewStyle(.circular).tint(.white)
                    } else {
                        Image(systemName: isValidURL ? "arrow.down.circle.fill" : "exclamationmark.circle")
                            .foregroundStyle(.white.opacity(0.95))
                    }
                    Text(isWorking ? "Downloading…" : "Import")
                        .font(.system(.headline, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isValidURL
                              ? AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xFF6A00), Color(hex: 0xFF5500)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing))
                              : AnyShapeStyle(Color.black.opacity(0.7)))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.2), radius: 10, y: 6)
            }
            .buttonStyle(.plain)
            .disabled(!isValidURL || isWorking)
            .animation(.easeInOut(duration: 0.18), value: isValidURL)

        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        // No appear animations, no extra backdrops — keeps presentation silky
    }

    private func submitIfPossible() {
        let t = scUrlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidURL, !t.isEmpty, !isWorking else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onSubmit(t)
    }
}
