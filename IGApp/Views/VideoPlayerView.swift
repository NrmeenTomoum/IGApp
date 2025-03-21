import SwiftUI
import AVKit
import AVFoundation

struct VideoPlayerView: View {
    let url: URL
    let isVisible: Bool
    @StateObject private var viewModel = VideoPlayerViewModel()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let player = viewModel.player {
                    VideoPlayerControllerRepresentable(player: player)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .overlay(
                            Button(action: {
                                Task {
                                    await viewModel.togglePlayback()
                                }
                            }) {
                                Rectangle()
                                    .fill(Color.clear)
                                    .overlay(
                                        Group {
                                            if viewModel.isPaused {
                                                Image(systemName: "play.circle.fill")
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fit)
                                                    .frame(width: 50, height: 50)
                                                    .foregroundColor(.white)
                                                    .opacity(0.8)
                                            }
                                        }
                                    )
                            }
                        )
                } else {
                    Rectangle()
                        .fill(Color(.systemGray6))
                        .overlay {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        }
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.setupPlayer(with: url)
            }
        }
        .onChange(of: isVisible) { newValue in
            viewModel.handleVisibilityChange(isVisible: newValue)
        }
        .onDisappear {
            Task {
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
        
        // Disable gesture recognizers in AVPlayerViewController
        controller.view.gestureRecognizers?.forEach { gesture in
            gesture.isEnabled = false
        }
        
        return controller
    }
    
    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        controller.player = player
    }
}

@MainActor
final class VideoPlayerViewModel: ObservableObject {
    @Published private(set) var player: AVPlayer?
    @Published private(set) var isPaused: Bool = false
    private var timeObserver: Any?
    private var loopObserver: NSObjectProtocol?
    private var playerItem: AVPlayerItem?
    private var isVisible = false
    
    
    func setupPlayer(with url: URL) async {
        // Cleanup existing player first
        await cleanup()
        
        do {
            // Configure audio session
            try await AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try await AVAudioSession.sharedInstance().setActive(true)
            
            // Create asset and player item
            let asset = AVURLAsset(url: url)
            let playerItem = AVPlayerItem(asset: asset)
            self.playerItem = playerItem
            
            // Create and configure player
            let player = AVPlayer(playerItem: playerItem)
            player.actionAtItemEnd = .none
            
            // Set up looping with weak self
            loopObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: playerItem,
                queue: .main) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        await self?.handlePlaybackEnd()
                    }
                }
            
            // Add periodic time observer with weak self
            let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
                guard let self = self else { return }
                self.handlePlaybackStall()
            }
            
            // Update state
            self.player = player
            
            // Start playback if visible
            if isVisible {
                try? await player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
                if !isPaused {
                    player.play()
                }
            }
        } catch {
            print("Failed to setup player for \(url): \(error)")
            await cleanup()
        }
    }
    
    private func handlePlaybackEnd() async {
        guard let currentPlayer = player, isVisible else { return }
        do {
            try await currentPlayer.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
            if !isPaused {
                currentPlayer.play()
            }
        } catch {
            print("Failed to handle playback end: \(error)")
        }
    }
    
    private func handlePlaybackStall() {
        guard let currentPlayer = player, isVisible, !isPaused else { return }
        if currentPlayer.timeControlStatus == .waitingToPlayAtSpecifiedRate {
            currentPlayer.playImmediately(atRate: 1.0)
        }
    }
    
    func togglePlayback() async {
        guard let currentPlayer = player else { return }
        
        if currentPlayer.timeControlStatus == .playing {
            currentPlayer.pause()
            isPaused = true
        } else {
            currentPlayer.play()
            isPaused = false
        }
    }
    
    func handleVisibilityChange(isVisible: Bool) {
        self.isVisible = isVisible
        guard let currentPlayer = player else { return }
        
        if isVisible {
            Task { @MainActor in
                try? await currentPlayer.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
                if !isPaused {
                    currentPlayer.play()
                }
            }
        } else {
            currentPlayer.pause()
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
        
        // Reset observers
        timeObserver = nil
        loopObserver = nil
        
        // Cleanup player
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        playerItem = nil
        
        // Deactivate audio session
        try? await AVAudioSession.sharedInstance().setActive(false)
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
