//
//  FeedView.swift
//  Hidden Gems
//
//  Created by Divine Davis on 3/16/26.
//

import SwiftUI
import Supabase

struct FeedView: View {
    @Environment(RecommendationsManager.self) private var recommendationsManager
    @Environment(SavedRestaurantsManager.self) private var savedManager
    @Environment(LikesManager.self) private var likesManager
    @Environment(CommentsManager.self) private var commentsManager
    @Environment(AuthManager.self) private var authManager
    @Environment(PostViewsManager.self) private var postViewsManager
    @Environment(FollowManager.self) private var followManager
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
            }
            // Hide the tab bar on downward scrolls past the top, show it
            // again on upward scrolls. Using onScrollGeometryChange (iOS
            // 18+) instead of a GeometryReader+preference because the
            // preference path was firing inconsistently and the tab bar
            // would stay stuck visible.
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.y
            } action: { oldY, newY in
                let delta = newY - oldY
                if delta > 6, isTabBarVisible, newY > 20 {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isTabBarVisible = false
                    }
                } else if delta < -6, !isTabBarVisible {
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
                let uid = authManager.currentUser.id
                // Load the seen set and follow list before sorting the
                // feed — on cold launch both this task and
                // ContentView.task fire concurrently, and if refreshFeed
                // won the race it would sort against empty sets
                // (surfacing seen posts at the top, and not elevating
                // posts liked by users you follow).
                // Loaded likes feed into the seen-set so historical likes
                // drop to the bottom tier — without this, the user's prior
                // likes resurface at the top on cold-launch.
                async let views: Void = postViewsManager.load(userId: uid)
                async let follows: Void = followManager.loadFollowing(userId: uid)
                async let likes: Void = likesManager.loadLiked(userId: uid)
                _ = await (views, follows, likes)
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
        .alert(
            "Bookmark failed",
            isPresented: Binding(
                get: { savedManager.lastError != nil },
                set: { if !$0 { savedManager.lastError = nil } }
            ),
            presenting: savedManager.lastError
        ) { _ in
            Button("OK", role: .cancel) { savedManager.lastError = nil }
        } message: { msg in
            Text(msg)
        }
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
            postViewsManager: postViewsManager,
            followManager: followManager
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
    @Environment(\.openURL) private var openURL
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

    /// Opens Apple Maps with the restaurant prefilled as the directions
    /// destination. Prefers stored coordinates over a string address
    /// since generic city names sometimes geocode to the wrong place.
    fileprivate func openInMaps(_ restaurant: Restaurant) {
        var components = URLComponents(string: "http://maps.apple.com/")!
        var items: [URLQueryItem] = []
        if restaurant.latitude != 0 || restaurant.longitude != 0 {
            items.append(URLQueryItem(name: "daddr",
                                      value: "\(restaurant.latitude),\(restaurant.longitude)"))
            items.append(URLQueryItem(name: "q", value: restaurant.name))
        } else if !restaurant.location.isEmpty {
            items.append(URLQueryItem(name: "daddr",
                                      value: "\(restaurant.name), \(restaurant.location)"))
        } else {
            return
        }
        components.queryItems = items
        if let url = components.url { openURL(url) }
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
                NavigationLink {
                    RestaurantDetailView(restaurant: recommendation.restaurant)
                } label: {
                    Text(recommendation.restaurant.name)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)

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

                    // Show the poster's own stars when available (the
                    // create form requires a rating going forward), and
                    // fall back to the community aggregate for legacy
                    // posts that predate the requirement.
                    if let userRating = recommendation.userRating {
                        UserRatingStars(rating: userRating, font: .subheadline)
                            .fixedSize()
                    } else {
                        RatingBadge(rating: recommendation.restaurant.rating, font: .subheadline)
                            .fixedSize()
                    }
                }

                Text(recommendation.restaurant.location)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .contentShape(Rectangle())
                    .onTapGesture { openInMaps(recommendation.restaurant) }

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
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
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
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
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
    @Environment(FollowManager.self) private var followManager

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
                    postViewsManager: postViewsManager,
                    followManager: followManager
                )
            }
        }
    }
}

/// Pushed when a user taps a restaurant name on a feed card. Lists
/// every post for that restaurant, with a Top / Recent toggle. Hits
/// the `feed` view directly (not the in-memory recommendations) so
/// the user sees every historical post, not just what's loaded into
/// the home feed's 200-row window.
struct RestaurantDetailView: View {
    let restaurant: Restaurant

    @State private var posts: [Recommendation] = []
    @State private var sortMode: SortMode = .top
    @State private var isLoading = true

    @Environment(LikesManager.self) private var likesManager
    @Environment(CommentsManager.self) private var commentsManager

    enum SortMode: String, CaseIterable, Identifiable {
        case top = "Top"
        case recent = "Recent"
        var id: String { rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Sort", selection: $sortMode) {
                    ForEach(SortMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                } else if posts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "fork.knife")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("No posts for this spot yet")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(posts) { rec in
                            RecommendationCard(recommendation: rec)
                                .padding(.bottom, 12)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(restaurant.name)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: sortMode) { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        // Sort by like_count for "top" (strongest engagement signal —
        // PostgREST can't order by a computed expression so summing
        // likes + comments would need a server-side view) and by
        // created_at for "recent."
        let orderColumn: String = sortMode == .top ? "like_count" : "created_at"
        do {
            let rows: [SupabaseFeedPost] = try await supabase
                .from("feed")
                .select()
                .eq("restaurant_id", value: restaurant.id.uuidString)
                .order(orderColumn, ascending: false)
                .limit(100)
                .execute()
                .value
            posts = rows.map { $0.toRecommendation() }
            likesManager.hydrate(from: rows)
            commentsManager.hydrateCounts(from: rows)
        } catch {
            debugLog("RestaurantDetailView fetch error", error)
        }
    }
}

#Preview {
    FeedView(showingCreatePost: .constant(false))
}
