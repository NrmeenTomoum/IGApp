import Foundation

enum Media: Identifiable {
    case photo(URL)
    case video(URL)
    
    // Conform to Identifiable using the URL as the unique identifier
    var id: URL {
        switch self {
        case .photo(let url): return url
        case .video(let url): return url
        }
    }
}