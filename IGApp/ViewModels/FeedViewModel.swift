import Foundation
import SwiftUI


@MainActor
final class FeedViewModel: ObservableObject {
    @Published private(set) var posts: [Post] = []
    private let imageCache = ImageCache.shared
    private let maxConcurrentVideos = 2
    
    init() {
        loadMockData()
    }
    
    func refreshFeed() async {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        loadMockData()
    }
    
    private func loadMockData() {
        // Create URLs for mock data
        let initialPosts = [
            Post(mediaType: .image,
                 imageURL: Bundle.main.url(forResource: "image1", withExtension: "jpg"),
                 caption: "Beautiful sunset 🌅"),
            
            Post(mediaType: .video,
                 videoURL: Bundle.main.url(forResource: "video1", withExtension: "mp4"),
                 caption: "Amazing moments! 🎥"),
            
            Post(mediaType: .mixed,
                 imageURL: Bundle.main.url(forResource: "image2", withExtension: "jpg"),
                 videoURL: Bundle.main.url(forResource: "video2", withExtension: "mp4"),
                 caption: "Mixed media post 📸🎬"),
            
            Post(mediaType: .image,
                 imageURL: Bundle.main.url(forResource: "image3", withExtension: "jpg"),
                 caption: "Nature's beauty 🌿"),
            
            Post(mediaType: .video,
                 videoURL: Bundle.main.url(forResource: "video3", withExtension: "mp4"),
                 caption: "City life 🌆")
        ]
        
        // Filter out posts with missing required URLs
        posts = initialPosts.filter { post in
            switch post.mediaType {
            case .image:
                guard let imageURL = post.imageURL,
                      FileManager.default.fileExists(atPath: imageURL.path) else {
                    return false
                }
                return true
                
            case .video:
                guard let videoURL = post.videoURL,
                      FileManager.default.fileExists(atPath: videoURL.path) else {
                    return false
                }
                return true
                
            case .mixed:
                guard let imageURL = post.imageURL,
                      let videoURL = post.videoURL,
                      FileManager.default.fileExists(atPath: imageURL.path),
                      FileManager.default.fileExists(atPath: videoURL.path) else {
                    return false
                }
                return true
            }
        }
    }
    
    deinit {
        // Clear image cache when view model is deallocated
        imageCache.clearCache()
    }
}
