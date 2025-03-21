//
//  Post.swift
//  IGApp
//
//  Created by Nermeen Tomoum on 19/03/2025.
//

import Foundation

enum MediaType {
    case image
    case video
    case mixed
}

struct Post: Identifiable {
    let id: UUID
    let mediaType: MediaType
    let imageURL: URL?
    let videoURL: URL?
    let caption: String
    let timestamp: Date
    
    init(id: UUID = UUID(), mediaType: MediaType, imageURL: URL? = nil, videoURL: URL? = nil, caption: String, timestamp: Date = Date()) {
        self.id = id
        self.mediaType = mediaType
        self.imageURL = imageURL
        self.videoURL = videoURL
        self.caption = caption
        self.timestamp = timestamp
    }
}