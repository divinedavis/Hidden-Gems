//
//  FeedView.swift
//  Hidden Gems
//
//  Created by Divine Davis on 3/16/26.
//

import SwiftUI

/// Emits the current vertical scroll offset of the feed's content in
/// the "feedScroll" coordinate space so the tab bar can hide on
/// downward scrolls and reappear on upward scrolls.
private struct FeedScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct FeedView: View {
    @Environment(RecommendationsManager.self) private var recommendationsManager
    @Environment(SavedRestaurantsManager.self) private var savedManager
    @Environment(LikesManager.self) private var likesManager
    @Environment(CommentsManager.self) private var commentsManager
    @Environment(AuthManager.self) private var authManager
    @Environment(PostViewsManager.self) private var postViewsManager
    @Binding var showingCreatePost: Bool

    @State private var isTabBarVisible = true
    @State private var lastScrollY: CGFloat = 0
    #if DEBUG
    @State private var debugCommentsRec: Recommendation?
    #endif

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(recommendationsManager.recommendations) { recommendation in
                        RecommendationCard(recommendation: recommendation)
                            .padding(.bottom, 12)
                    }
                }
                .padding(.horizontal)
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: FeedScrollOffsetKey.self,
                            value: proxy.frame(in: .named("feedScroll")).minY
                        )
                    }
                )
            }
            .coordinateSpace(name: "feedScroll")
            .onPreferenceChange(FeedScrollOffsetKey.self) { newY in
                let delta = newY - lastScrollY
                // Threshold prevents jitter from tiny movements.
                // Delta < 0 means content scrolled up (user scrolling down) → hide.
                // Delta > 0 means content scrolled down (user scrolling up) → show.
                if delta < -6, isTabBarVisible, newY < -20 {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isTabBarVisible = false
                    }
                } else if delta > 6, !isTabBarVisible {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isTabBarVisible = true
                    }
                }
                lastScrollY = newY
            }
            .refreshable {
                await refreshFeed()
            }
            .task(id: authManager.currentUser.id) {
                // Pinning the task to the user's id means it fires
                // once when a session is established (or changes),
                // not every time FeedView re-appears. Without the
                // id, pushing into a profile and popping back would
                // re-trigger the fetch, re-sort the feed, and bump
                // the post the user just viewed down into the seen
                // pool — which looked like the card they were just
                // reading "disappeared." Manual refresh still works
                // via pull-to-refresh.
                guard authManager.isSignedIn else { return }
                // Load the seen set before sorting the feed — on
                // cold launch both this task and ContentView.task
                // fire concurrently, and if refreshFeed won the
                // race it would sort against an empty viewedPostIds
                // and render already-seen posts at the top again.
                await postViewsManager.load(userId: authManager.currentUser.id)
                await refreshFeed()
            }
            .navigationTitle("Hidden Gems")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image(systemName: "gem.fill")
                            .font(.title3)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Text("Hidden Gems")
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCreatePost = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
        }
        .toolbar(isTabBarVisible ? .visible : .hidden, for: .tabBar)
        #if DEBUG
        .sheet(item: $debugCommentsRec) { rec in
            CommentsView(recommendation: rec)
                .environment(commentsManager)
                .environment(authManager)
        }
        .task(id: recommendationsManager.recommendations.count) {
            // HG_TEST_SHEET=comments auto-presents CommentsView against
            // the first feed recommendation so the screenshot script can
            // capture the modal without needing taps into the Simulator.
            guard ProcessInfo.processInfo.environment["HG_TEST_SHEET"] == "comments" else { return }
            guard debugCommentsRec == nil,
                  let first = recommendationsManager.recommendations.first else { return }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            debugCommentsRec = first
        }
        #endif
    }
    
    private func refreshFeed() async {
        await recommendationsManager.fetchFeed(
            likesManager: likesManager,
            commentsManager: commentsManager,
            postViewsManager: postViewsManager
        )
    }
}

struct RecommendationCard: View {
    let recommendation: Recommendation
    @Environment(SavedRestaurantsManager.self) private var savedManager
    @Environment(LikesManager.self) private var likesManager
    @Environment(CommentsManager.self) private var commentsManager
    @Environment(AuthManager.self) private var authManager
    @Environment(PostViewsManager.self) private var postViewsManager
    @State private var showingComments = false
    @State private var dwellTask: Task<Void, Never>?

    private let dwellThreshold: UInt64 = 2_000_000_000 // 2s

    /// Records this card as seen — either because the user dwelled on
    /// it in the feed for `dwellThreshold`, or because they engaged
    /// (tap photo, open comments, like, save, etc.). Seen posts drop
    /// to the bottom of the next feed refresh.
    private func markSeen() {
        postViewsManager.markViewed(recommendation.id, by: authManager.currentUser.id)
    }

    /// The photos to show in the card, in order. Prefers the post's
    /// own uploaded array; falls back to the restaurant's cover photo
    /// so a post without photos still shows something when the
    /// restaurant has its own image.
    private var cardImages: [String] {
        if !recommendation.imageURLs.isEmpty {
            return recommendation.imageURLs
        }
        let fallback = recommendation.restaurant.imageURL
        return fallback.isEmpty ? [] : [fallback]
    }

    @ViewBuilder
    private var photoCarousel: some View {
        let images = cardImages
        if images.count > 1 {
            TabView {
                ForEach(Array(images.enumerated()), id: \.offset) { _, url in
                    SafeAsyncImage(urlString: url)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .frame(maxWidth: .infinity)
            .aspectRatio(4/3, contentMode: .fit)
            .background(Color.gray.opacity(0.2))
            .clipped()
        } else {
            SafeAsyncImage(urlString: images.first ?? "")
                .frame(maxWidth: .infinity)
                .aspectRatio(4/3, contentMode: .fit)
                .background(Color.gray.opacity(0.2))
                .clipped()
        }
    }

    private var shareMessage: String {
        let r = recommendation.restaurant
        return "\(r.name) — \(r.cuisine) in \(r.location). Found on Hidden Gems."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // User info header
            NavigationLink(destination: ProfileView(user: recommendation.user)) {
                HStack {
                    UserAvatar(user: recommendation.user, size: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(recommendation.user.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(recommendation.user.username)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(shortRelative(from: recommendation.date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding()
            
            // Restaurant image(s). Multi-image posts render as a
            // paged TabView so the user can swipe left/right between
            // photos; single-image posts stay a plain SafeAsyncImage
            // to avoid the TabView's layout overhead.
            photoCarousel

            // Restaurant info
            VStack(alignment: .leading, spacing: 4) {
                Text(recommendation.restaurant.name)
                    .font(.title3)
                    .fontWeight(.bold)

                // Meta row: cuisine • $$$ ............... ★ rating
                HStack(spacing: 6) {
                    Text(recommendation.restaurant.cuisine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize()
                    Text("•")
                        .foregroundStyle(.secondary)
                    Text(String(repeating: "$", count: recommendation.restaurant.priceLevel))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize()

                    Spacer(minLength: 6)

                    RatingBadge(rating: recommendation.restaurant.rating, font: .subheadline)
                        .fixedSize()
                }

                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.caption)
                    Text(recommendation.restaurant.location)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)

                // Vibe tags — horizontally scrollable strip sitting
                // between the location row and the caption.
                VibeTagStrip(tags: recommendation.vibeTags)
                    .padding(.top, 6)

                // User's note
                if !recommendation.note.isEmpty {
                    Text(recommendation.note)
                        .font(.body)
                        .padding(.top, 8)
                }
                
                // Action buttons — using onTapGesture directly (Button was
                // not receiving taps inside the feed's ScrollView+LazyVStack
                // on iOS 26; bypassing Button makes taps reliable).
                HStack(spacing: 20) {
                    HStack(spacing: 4) {
                        Image(systemName: likesManager.isLiked(recommendation) ? "heart.fill" : "heart")
                            .font(.title3)
                            .foregroundStyle(likesManager.isLiked(recommendation) ? .red : .primary)
                            .scaleEffect(likesManager.isLiked(recommendation) ? 1.15 : 1.0)

                        let count = likesManager.likeCount(for: recommendation)
                        if count > 0 {
                            Text("\(count)")
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 8)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        debugLog("Like tapped", recommendation.restaurant.name)
                        markSeen()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            likesManager.toggleLike(recommendation, by: authManager.currentUser.id)
                        }
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right")
                            .font(.title3)
                            .foregroundStyle(.primary)

                        let count = commentsManager.commentCount(for: recommendation)
                        if count > 0 {
                            Text("\(count)")
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 8)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        debugLog("Comment tapped", recommendation.restaurant.name)
                        markSeen()
                        showingComments = true
                    }

                    ShareLink(item: shareMessage) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title3)
                            .foregroundStyle(.primary)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 8)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Image(systemName: savedManager.isSaved(recommendation.restaurant) ? "bookmark.fill" : "bookmark")
                        .font(.title3)
                        .scaleEffect(savedManager.isSaved(recommendation.restaurant) ? 1.15 : 1.0)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 8)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            debugLog("Save tapped", recommendation.restaurant.name)
                            markSeen()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                savedManager.toggleSave(
                                    recommendation.restaurant,
                                    by: authManager.currentUser.id
                                )
                            }
                        }
                }
                .foregroundStyle(.primary)
                .padding(.top, 8)
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        .onAppear {
            // Start a dwell timer. If the card stays on screen long
            // enough, flip it to seen. Cancelled if the user scrolls
            // past before the threshold.
            dwellTask = Task {
                try? await Task.sleep(nanoseconds: dwellThreshold)
                guard !Task.isCancelled else { return }
                markSeen()
            }
        }
        .onDisappear {
            dwellTask?.cancel()
            dwellTask = nil
        }
        .sheet(isPresented: $showingComments) {
            CommentsView(recommendation: recommendation)
                .environment(commentsManager)
                .environment(authManager)
        }
    }
}

/// Tag-filtered feed pushed when the user taps a hashtag chip on
/// any card. Reads from the in-memory `RecommendationsManager` so
/// it shows up immediately without a round trip; if the feed hasn't
/// been populated yet (e.g. tapping a tag from a profile card before
/// the Feed tab has loaded) it fetches on appear.
struct TagFeedView: View {
    let tag: String
    @Environment(RecommendationsManager.self) private var recommendationsManager
    @Environment(LikesManager.self) private var likesManager
    @Environment(CommentsManager.self) private var commentsManager
    @Environment(PostViewsManager.self) private var postViewsManager

    private var normalized: String { Vibe.normalize(tag) }

    private var matches: [Recommendation] {
        recommendationsManager.recommendations.filter { rec in
            rec.vibeTags.contains { Vibe.normalize($0) == normalized }
        }
    }

    var body: some View {
        ScrollView {
            if matches.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "number")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No posts with this tag yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 80)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(matches) { recommendation in
                        RecommendationCard(recommendation: recommendation)
                            .padding(.bottom, 12)
                    }
                }
                .padding(.horizontal)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("#\(RestaurantMetaInfo.displayTag(normalized))")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if recommendationsManager.recommendations.isEmpty {
                await recommendationsManager.fetchFeed(
                    likesManager: likesManager,
                    commentsManager: commentsManager,
                    postViewsManager: postViewsManager
                )
            }
        }
    }
}

#Preview {
    FeedView(showingCreatePost: .constant(false))
}
