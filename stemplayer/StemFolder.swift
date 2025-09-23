//
//  StemFolder.swift
//  stemplayer
//
//  Created by Andrew Arshia Almasi on 9/20/25.
//

import Foundation
import UniformTypeIdentifiers
import SwiftData

@Model
class StemFolder: Identifiable, Equatable, Codable {
    var stemNames: [String] { stems.map { $0.displayName } }

    init(id: UUID = UUID(), name: String, url: URL, stems: [StemFile] = []) {
        self.id = id
        self.name = name
        self.url = url
        self.stems = stems
    }
    
    struct StemFile: Identifiable, Equatable, Codable {
        var id = UUID()
        var displayName: String
        var bookmark: Data

        func makeResource() -> SecurityScopedResource? {
            SecurityScopedResource(bookmarkData: bookmark)
        }
    }

    @Attribute(.unique) var id: UUID
    var name: String
    var url: URL
    var stems: [StemFile]

    // MARK: - Codable (manual so we control what's encoded/decoded)

    private enum CodingKeys: String, CodingKey {
        case id, name, url, stems
    }

    required convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        let name = try container.decode(String.self, forKey: .name)
        let url = try container.decode(URL.self, forKey: .url)
        let stems = try container.decodeIfPresent([StemFile].self, forKey: .stems) ?? []
        self.init(id: id, name: name, url: url, stems: stems)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(url, forKey: .url)
        try container.encode(stems, forKey: .stems)
    }

    // Convenience to recreate SecurityScopedResources
    func makeStemResources() -> [SecurityScopedResource] {
        stems.compactMap { $0.makeResource() }
    }
}


final class SecurityScopedResource: Codable {
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
