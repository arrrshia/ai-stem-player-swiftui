//
//  LibraryStore.swift
//  stemplayer
//
//  Created by Andrew Arshia Almasi on 9/20/25.
//

import Foundation

struct DownloadedTrack: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let url: URL
}
