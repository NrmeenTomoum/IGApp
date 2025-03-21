import SwiftUI
import AVKit
import AVFoundation

struct VideoPlayerView: View {
    let url: URL
    let isVisible: Bool
    @StateObject private var viewModel = VideoPlayerViewModel()
    
    var body: some View {
        ZStack {
            if let player = viewModel.player {
                VideoPlayerControllerRepresentable(player: player)
                    .aspectRatio(contentMode: .fill)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color(.systemGray6))
                    .overlay {
                        Image(systemName: "play.circle")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 30, height: 30)
                            .foregroundColor(.gray)
                    }
            }
        }
        .task {
            await viewModel.setupPlayer(with: url)
        }
        .onChange(of: isVisible) { newValue in
            Task { @MainActor in
                await viewModel.handleVisibilityChange(isVisible: newValue)
            }
        }
        .onDisappear {
            Task { @MainActor in
                await viewModel.cleanup()
            }
        }
    }
}

private struct VideoPlayerControllerRepresentable: UIViewControllerRepresentable {
    let player: AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspectFill
        controller.view.backgroundColor = .clear
        
        // Disable user interaction
        controller.view.isUserInteractionEnabled = false
        
        return controller
    }
    
    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        if controller.player !== player {
            controller.player = player
        }
    }
}

@MainActor
final class VideoPlayerViewModel: ObservableObject {
    @Published private(set) var player: AVPlayer?
    private var timeObserver: Any?
    private var loopObserver: NSObjectProtocol?
    private var playerItem: AVPlayerItem?
    private var isVisible = false
    
    func setupPlayer(with url: URL) async {
        await cleanup()
        
        do {
            // Create asset and load essential properties
            let asset = AVURLAsset(url: url)
            
            // Load asset properties
            await asset.loadValues(forKeys: ["playable", "duration"])
            
            guard asset.isPlayable else {
                print("Asset is not playable: \(url)")
                return
            }
            
            // Create player item
            let playerItem = AVPlayerItem(asset: asset)
            self.playerItem = playerItem
            
            // Configure player
            let newPlayer = AVPlayer(playerItem: playerItem)
            newPlayer.isMuted = true
            newPlayer.volume = 0
            newPlayer.actionAtItemEnd = .none
            
            // Set up looping
            loopObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: playerItem,
                queue: .main) { [weak self] _ in
                    self?.handlePlaybackEnd()
                }
            
            // Add periodic time observer for stall handling
            let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            timeObserver = newPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
                self?.handlePlaybackStall()
            }
            
            // Update state
            self.player = newPlayer
            
            // Start playback if visible
            if isVisible {
                try? await newPlayer.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
                newPlayer.play()
            }
            
        } catch {
            print("Failed to setup player for \(url): \(error)")
        }
    }
    
    private func handlePlaybackEnd() {
        Task { @MainActor in
            guard let player = player, isVisible else { return }
            try? await player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
            player.play()
        }
    }
    
    private func handlePlaybackStall() {
        guard let player = player, isVisible else { return }
        if player.timeControlStatus == .waitingToPlayAtSpecifiedRate {
            player.playImmediately(atRate: 1.0)
        }
    }
    
    func handleVisibilityChange(isVisible: Bool) async {
        self.isVisible = isVisible
        guard let player = player else { return }
        
        if isVisible {
            try? await player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
            player.play()
        } else {
            player.pause()
        }
    }
    
    func cleanup() async {
        // Remove observers
        if let timeObserver = timeObserver, let player = player {
            player.removeTimeObserver(timeObserver)
        }
        if let loopObserver = loopObserver {
            NotificationCenter.default.removeObserver(loopObserver)
        }
        
        // Reset state
        timeObserver = nil
        loopObserver = nil
        
        // Cleanup player
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        playerItem = nil
    }
    
    deinit {
        Task { @MainActor in
            await cleanup()
        }
    }
}

// MARK: - Visibility Tracking

struct VisibilityAwareModifier: ViewModifier {
    @State private var viewFrame: CGRect = .zero
    let onVisibilityChanged: (Bool) -> Void
    
    func body(content: Content) -> some View {
        content
            .background(
                VisibilityTracker(viewFrame: $viewFrame, onVisibilityChanged: onVisibilityChanged)
            )
    }
}

private struct VisibilityTracker: UIViewRepresentable {
    @Binding var viewFrame: CGRect
    let onVisibilityChanged: (Bool) -> Void
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            let newFrame = uiView.convert(uiView.bounds, to: nil)
            if newFrame != viewFrame {
                viewFrame = newFrame
                let isVisible = uiView.window != nil && 
                    !newFrame.intersects(.zero) &&
                    !newFrame.isNull &&
                    !newFrame.isEmpty &&
                    newFrame.intersects(UIScreen.main.bounds)
                onVisibilityChanged(isVisible)
            }
        }
    }
}

extension View {
    func trackVisibility(onChange: @escaping (Bool) -> Void) -> some View {
        modifier(VisibilityAwareModifier(onVisibilityChanged: onChange))
    }
}
