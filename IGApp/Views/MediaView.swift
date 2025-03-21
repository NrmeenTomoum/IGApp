//
//  MediaView.swift
//  IGApp
//
//  Created by Nermeen Tomoum on 19/03/2025.
//
import SwiftUI


struct MediaView: View {
    let media: Media
    
    var body: some View {
        switch media {
        case .photo(let url):
            CachedImage(url: url)
        case .video(let url):
            VideoPlayerView(url: url, isVisible: true)
        }
    }
}
