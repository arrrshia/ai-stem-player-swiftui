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
    @Published private(set)var folders: [StemFolder] = []
    let container = try! ModelContainer(for: StemFolder.self)
    let statusList = ["loading stems", "saving stems", "asleep"]
    @Published var statusCurrent: String = "asleep"

    init(){
        self.folders = loadFolders()
    }
    
    func loadFolders() -> [StemFolder] {
        let context = container.mainContext
        let stemFolders = FetchDescriptor<StemFolder>()
        return (try? context.fetch(stemFolders)) ?? []
    }
    
    // Accepts a folder URL from the document picker, scans 4 audio files, and stores it
    func addFolder(_ folderURL: URL) {
        statusCurrent = statusList[1]
        print("adding to swift data")
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
        print(audioURLs)
        // Keep only 4, sorted to a predictable order
        let sorted = sortStems(audioURLs)
        guard sorted.count == 4 else { return } // enforce 4 stems for this flow
        print(sorted)
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
        print("added", item)
        if context.hasChanges == true
        { try? context.save() } else { print("no changes") }
        folders = loadFolders()
        statusCurrent = statusList[2]
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
    
    // MARK: API USAGE
    func splitTrack(_ fileURL: URL) {
        statusCurrent = "Let's split our song"
        let client = AudioSeparatorAPIClient(apiURL: "https://arrrshia--audio-separator-api.modal.run")
        
        Task {
            let hasAccess = fileURL.startAccessingSecurityScopedResource()
            defer { if hasAccess { fileURL.stopAccessingSecurityScopedResource() } }
            
            do {
                var params = SeparatorParams()
                // Either pick a valid model or let the server default:
                params.models = ["htdemucs.yaml"]
                
                // 1) submit
                let submitted = try await client.separateAudio(fileURL: fileURL, params: params)
                let taskID = submitted.task_id
                print("Job submitted! Task ID:", taskID)
                
                // Prepare the destination folder *before* downloading
                let baseName = fileURL.deletingPathExtension().lastPathComponent
                let folderName = "\(baseName) Stems"
                let tempFolder = FileManager.default.temporaryDirectory.appendingPathComponent(folderName, isDirectory: true)
                try? FileManager.default.createDirectory(at: tempFolder, withIntermediateDirectories: true)
                
                while true {
                    let status = try await client.getJobStatus(taskID)
                    if let p = status.progress {
                        print("Progress: \(p)%")
                        statusCurrent = "Splitting song: \(p)%"
                    }
                    
                    switch status.status.lowercased() {
                    case "completed":
                        guard let files = status.files else { throw NSError(domain: "AudioSeparator", code: -2, userInfo: [NSLocalizedDescriptionKey: "No files returned"])}
                        statusCurrent = "Downloading stems"
                            switch files {
                            case .map(let hashToName):
                                for (hash, filename) in hashToName {
                                    if filename.contains("Drums") {statusCurrent="Downloading drums"}
                                    if filename.contains("Vocals") {statusCurrent="Downloading vocals"}
                                    if filename.contains("Other") {statusCurrent="Downloading everything else"}

                                    let outURL = tempFolder.appendingPathComponent(filename)
                                    _ = try await client.downloadFileByHash(
                                        taskID: taskID,
                                        fileHash: hash,
                                        filename: filename,
                                        outputURL: outURL
                                    )
                                    print("downloaded", outURL.path)
                                }
                                
                            case .list(let filenames):
                                for filename in filenames {
                                    let outURL = tempFolder.appendingPathComponent(filename)
                                    _ = try await client.downloadFile(taskID: taskID, filename: filename, outputURL: outURL)
                                    print("Downloaded:", outURL.path)
                                }
                            }
                        await MainActor.run { [weak self] in
                            self?.addFolder(tempFolder)
                        }
                        return
                        
                    case "error":
                        throw NSError(domain: "AudioSeparator", code: -1, userInfo: [NSLocalizedDescriptionKey: "Remote job failed"])
                        
                    default:
                        try await Task.sleep(nanoseconds: 2_000_000_000)
                    }
                }
            } catch {
                print("Split failed:", error.localizedDescription)
                if let ver = try? await client.getServerVersion() {
                    print("Server version:", ver)
                }
            }
        }
    }
    func deleteStem(_ folder: StemFolder) {
        let context = container.mainContext
        context.delete(folder)
        try? context.save()
        folders = loadFolders()
    }
}
