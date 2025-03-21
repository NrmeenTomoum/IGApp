import SwiftUI
import AVKit

struct PostView: View {
    let post: Post
    @State private var selectedTab = 0
    @State private var isVisible = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Media Content
            mediaContent
                .frame(maxWidth: .infinity)
                .frame(height: 400)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Caption and Timestamp
            VStack(alignment: .leading, spacing: 4) {
                Text(post.caption)
                    .font(.body)
                    .padding(.horizontal)
                
                Text(post.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(Color(.systemBackground))
        .trackVisibility { visible in
            isVisible = visible
        }
    }
    
    @ViewBuilder
    private var mediaContent: some View {
        switch post.mediaType {
        case .image:
            if let imageURL = post.imageURL {
                CachedImage(url: imageURL)
            }
            
        case .video:
            if let videoURL = post.videoURL {
                VideoPlayerView(url: videoURL, isVisible: isVisible)
            }
            
        case .mixed:
            TabView(selection: $selectedTab) {
                // Image Tab
                if let imageURL = post.imageURL {
                    CachedImage(url: imageURL)
                        .tag(0)
                }
                
                // Video Tab
                if let videoURL = post.videoURL {
                    VideoPlayerView(url: videoURL, isVisible: isVisible && selectedTab == 1)
                        .tag(1)
                }
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .overlay(alignment: .topTrailing) {
                mediaTypeIndicator
            }
        }
    }
    
    private var mediaTypeIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: "photo")
                .foregroundColor(selectedTab == 0 ? .white : .gray)
            
            Image(systemName: "video")
                .foregroundColor(selectedTab == 1 ? .white : .gray)
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .padding(8)
    }
}

struct CachedImage: View {
    let url: URL
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var hasError = false
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if isLoading {
                loadingView
            } else if hasError {
                errorView
            }
        }
        .task {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        // Check cache first
        if let cachedImage = ImageCache.shared.getImage(for: url) {
            self.image = cachedImage
            self.isLoading = false
            return
        }
        
        // Load from URL
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let loadedImage = UIImage(data: data) else {
                throw URLError(.badServerResponse)
            }
            
            // Cache the image
            ImageCache.shared.setImage(loadedImage, for: url)
            
            // Update UI
            self.image = loadedImage
            self.isLoading = false
        } catch {
            self.hasError = true
            self.isLoading = false
            print("Failed to load image: \(error)")
        }
    }
    
    private var loadingView: some View {
        Rectangle()
            .fill(Color(.systemGray6))
            .overlay {
                Image(systemName: "photo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 30, height: 30)
                    .foregroundColor(.gray)
            }
    }
    
    private var errorView: some View {
        Rectangle()
            .fill(Color(.systemGray6))
            .overlay {
                Image(systemName: "exclamationmark.triangle")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 30, height: 30)
                    .foregroundColor(.gray)
            }
    }
}
