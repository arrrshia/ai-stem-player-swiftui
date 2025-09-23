//
//  StemLibrary.swift
//  stemplayer
//
//  Created by Andrew Arshia Almasi on 9/27/25.
//

import Foundation
import SwiftData

@MainActor
final class StemLibrary: ObservableObject {
    var folders: [StemFolder] = []
    let container = try! ModelContainer(for: StemFolder.self)
    
    init(){
        self.folders = loadFolders()
    }
    
    func loadFolders() -> [StemFolder] {
        let context = container.mainContext
        let stemFolders = FetchDescriptor<StemFolder>()
        let folders = try! context.fetch(stemFolders)
        return folders
    }
    
    // Accepts a folder URL from the document picker, scans 4 audio files, and stores it
    func addFolder(_ folderURL: URL) {
        let context = container.mainContext

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
        let duplicateCheck = FetchDescriptor<StemFolder>(
            predicate: #Predicate { folder in
                folder.name == item.name
            }
        )
        let duplicate = try? context.fetch(duplicateCheck)
        if duplicate?.isEmpty == true {
            print("inserted new", item.name)
            context.insert(item)
        }
        
        if context.hasChanges == true
        { try? context.save() } else { print("no changes") }
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
