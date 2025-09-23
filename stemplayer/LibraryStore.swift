//
//  LibraryStore.swift
//  stemplayer
//
//  Created by Andrew Arshia Almasi on 9/20/25.
//

import Foundation

struct DownloadedTrack: Identifiable, Equatable, Codable {
    var id = UUID()
    var title: String
    var url: URL
}
