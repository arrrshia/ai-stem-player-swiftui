//
//  SecurityScopedResource.swift
//  stemplayer
//
//  Created by Andrew Arshia Almasi on 9/28/25.
//

import Foundation

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
