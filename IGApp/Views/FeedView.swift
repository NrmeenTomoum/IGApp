import SwiftUI

struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    
    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.posts) { post in
                    PostView(post: post)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Instagram Feed")
            .refreshable {
                await viewModel.refreshFeed()
            }
        }
        .background(Color(.systemGroupedBackground))
    }
}
