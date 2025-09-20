//
//  StemFolder.swift
//  stemplayer
//
//  Created by Andrew Arshia Almasi on 9/20/25.
//

import Foundation
import UniformTypeIdentifiers

struct StemFolder: Identifiable, Equatable {
    struct StemFile: Identifiable, Equatable {
        let id = UUID()
        let displayName: String
        let bookmark: Data

        func makeResource() -> SecurityScopedResource? {
            SecurityScopedResource(bookmarkData: bookmark)
        }
    }

    let id = UUID()
    let name: String
    let url: URL
    let stems: [StemFile]

    var stemNames: [String] { stems.map { $0.displayName } }

    func makeStemResources() -> [SecurityScopedResource] {
        stems.compactMap { $0.makeResource() }
    }
}

final class SecurityScopedResource {
    let url: URL
    private let needsStop: Bool
    private var hasStopped = false

    init?(bookmarkData: Data) {
        var isStale = false
        guard let resolved = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }

        needsStop = resolved.startAccessingSecurityScopedResource()
        url = resolved
    }

    func stopAccessing() {
        guard needsStop, !hasStopped else { return }
        resolvedStop()
    }

    private func resolvedStop() {
        url.stopAccessingSecurityScopedResource()
        hasStopped = true
    }

    deinit {
        stopAccessing()
    }
}

@MainActor
final class StemLibrary: ObservableObject {
    @Published private(set) var folders: [StemFolder] = []

    // Accepts a folder URL from the document picker, scans 4 audio files, and stores it
    func addFolder(_ folderURL: URL) {
        // use security scope while scanning
        let needsStop = folderURL.startAccessingSecurityScopedResource()
        defer { if needsStop { folderURL.stopAccessingSecurityScopedResource() } }

        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isRegularFileKey, .nameKey, .isDirectoryKey]
        guard let enumerator = fm.enumerator(at: folderURL, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { return }

        var audioURLs: [URL] = []
        let exts: Set<String> = ["m4a","mp3","wav","aif","aiff","flac","caf"]
        for case let fileURL as URL in enumerator {
            if exts.contains(fileURL.pathExtension.lowercased()) {
                audioURLs.append(fileURL)
            }
        }

        // Keep only 4, sorted to a predictable order
        let sorted = sortStems(audioURLs)
        guard sorted.count == 4 else { return } // enforce 4 stems for this flow

        let stemFiles: [StemFolder.StemFile] = sorted.compactMap { url in
            guard let bookmark = try? url.bookmarkData(
                options: [.minimalBookmark],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            ) else { return nil }
            let name = url.deletingPathExtension().lastPathComponent
            return StemFolder.StemFile(displayName: name, bookmark: bookmark)
        }

        guard stemFiles.count == 4 else { return }

        let folderName = folderURL.lastPathComponent
        let item = StemFolder(name: folderName, url: folderURL, stems: stemFiles)

        // Replace existing entry for same folder if present
        if let idx = folders.firstIndex(where: { $0.url == folderURL }) {
            folders[idx] = item
        } else {
            folders.insert(item, at: 0)
        }
    }

    private func sortStems(_ urls: [URL]) -> [URL] {
        // Score by stem name if present; else by numeric prefix; else alphabetical
        func score(_ url: URL) -> (Int, Int, String) {
            let name = url.deletingPathExtension().lastPathComponent.lowercased()

            // Common stem keywords
            let keywords: [(String, Int)] = [
                ("vocals", 0), ("vocal", 0), ("vox", 0),
                ("drums", 1), ("drum", 1), ("perc", 1),
                ("bass", 2),
                ("other", 3), ("instr", 3), ("accompaniment", 3)
            ]
            if let k = keywords.first(where: { name.contains($0.0) }) {
                return (k.1, 0, name)
            }

            // Leading number e.g. "1_", "02-", etc.
            if let match = name.split(whereSeparator: { !$0.isNumber }).first,
               let n = Int(match) {
                return (n, 1, name)
            }

            return (Int.max, 2, name)
        }

        return urls.sorted { a, b in
            let sa = score(a), sb = score(b)
            if sa.0 != sb.0 { return sa.0 < sb.0 }
            if sa.1 != sb.1 { return sa.1 < sb.1 }
            return sa.2 < sb.2
        }
    }
}
