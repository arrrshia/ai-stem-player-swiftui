//
//  GlassFolderList.swift
//  stemplayer
//
//  Created by Andrew Arshia Almasi on 9/28/25.
//

import SwiftUI

// MARK: - Glass List

struct GlassFolderList: View {
    let library: StemLibrary
    let selectedFolderID: StemFolder.ID?
    var onTapFolder: (StemFolder) -> Void
    var onPressLoad: (StemFolder) -> Void
    var onSwipeFolder: (StemFolder) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header row (unchanged)
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
                List {
                    ForEach(library.folders) { folder in
                        let isSelected = folder.id == selectedFolderID

                        // === Row content (visually identical) ===
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
                                    .background(Capsule().fill(Color.green.opacity(0.18)))
                                    .overlay(Capsule().stroke(Color.green.opacity(0.35), lineWidth: 1))
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
                                    .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
                                    .foregroundStyle(.primary)
                                }
                                .buttonStyle(PressableStyle())
                                .transition(.opacity.combined(with: .scale))
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .contentShape(Rectangle())
                        .onTapGesture { onTapFolder(folder) }
                        // Glass card background per row
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(isSelected ? Color.green.opacity(0.35) : Color.white.opacity(0.18), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
                                .padding(.horizontal, 12)   // match outer spacing
                                .padding(.vertical, 4)
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                onSwipeFolder(folder)
                            } label: {
                                Label("Delete", systemImage: "trash")
                                    
                            }
                        }
                        .listRowSeparator(.hidden) // mimic card-only look
                    }
                }
                .listStyle(.plain)
                .scrollIndicators(.hidden)
                .scrollContentBackground(.hidden) // keep the glass container’s background
                .frame(maxHeight: 160)            // same height cap as before
                .padding(.bottom, 12)             // match previous bottom padding
            }
        }
        // Outer glass container (unchanged)
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
