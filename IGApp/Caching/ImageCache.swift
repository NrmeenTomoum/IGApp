import UIKit

final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()
    
    private init() {
        // Configure cache limits
        cache.countLimit = 100 // Maximum number of images to cache
        cache.totalCostLimit = 1024 * 1024 * 100 // 100 MB limit
    }
    
    func getImage(for url: URL) -> UIImage? {
        return cache.object(forKey: url.absoluteString as NSString)
    }
    
    func setImage(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url.absoluteString as NSString)
    }
    
    func removeImage(for url: URL) {
        cache.removeObject(forKey: url.absoluteString as NSString)
    }
    
    func clearCache() {
        cache.removeAllObjects()
    }
} 