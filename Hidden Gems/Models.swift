//
//  Models.swift
//  Hidden Gems
//
//  Created by Divine Davis on 3/16/26.
//

import Foundation
import SwiftUI
import Supabase

struct Restaurant: Identifiable {
    var id: UUID = UUID()
    let name: String
    let cuisine: String
    let location: String
    let imageURL: String
    let rating: Double
    let priceLevel: Int // 1-4 ($-$$$$)
    let description: String
    /// Stable identifier from Apple Maps when the place was picked
    /// from MKLocalSearch. Empty for manually-added places. Used as
    /// the upsert conflict target so multiple posts about the same
    /// Apple POI share one `restaurants` row.
    var applePlaceID: String = ""
    var latitude: Double = 0
    var longitude: Double = 0
}

struct Recommendation: Identifiable {
    var id: UUID = UUID()
    let restaurant: Restaurant
    let user: User
    let note: String
    let date: Date
    let isSaved: Bool
    var vibeTags: [String] = []
    /// Photos the poster attached (max 5). If empty, the card falls
    /// back to the restaurant's own cover photo. First entry doubles
    /// as the profile-grid thumbnail and comments-sheet header.
    var imageURLs: [String] = []
}

// Curated vibe suggestions surfaced in the tag picker + Search
// filter row. Users can still type their own free-form tags; these
// are just the ones we officially promote.
enum Vibe {
    static let curated: [String] = [
        "Date Night Spots",
        "Quick Lunch",
        "Late Night Eats",
        "Lowkey Vibes",
        "Good for Solo Dining"
    ]

    /// Lowercased, trimmed form stored in Supabase so
    /// "Date Night Spots" and "date night spots" are the same tag.
    static func normalize(_ tag: String) -> String {
        tag.trimmingCharacters(in: .whitespaces).lowercased()
    }
}

struct Comment: Identifiable, Equatable {
    var id: UUID = UUID()
    let user: User
    let text: String
    let date: Date
    var likeCount: Int = 0
    var parentCommentId: UUID? = nil

    static func == (lhs: Comment, rhs: Comment) -> Bool {
        lhs.id == rhs.id
    }
}

struct User: Identifiable, Equatable, Hashable {
    var id: UUID = UUID()
    let name: String
    let username: String
    var profileImageURL: String
    var bio: String = ""
    let followersCount: Int
    let followingCount: Int

    static func == (lhs: User, rhs: User) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// Codable struct matching a row from the Supabase 'comments' table
// joined with the user who wrote the comment plus the ids of every
// user who liked it (via the `comment_likes` FK relationship).
struct SupabaseComment: Codable {
    let id: UUID
    let postId: UUID
    let userId: UUID
    let text: String
    let createdAt: Date
    let parentCommentId: UUID?
    let users: Author
    let commentLikes: [LikeRow]?

    struct Author: Codable {
        let name: String
        let username: String
        let profileImageUrl: String?

        enum CodingKeys: String, CodingKey {
            case name, username
            case profileImageUrl = "profile_image_url"
        }
    }

    struct LikeRow: Codable {
        let userId: UUID
        enum CodingKeys: String, CodingKey { case userId = "user_id" }
    }

    enum CodingKeys: String, CodingKey {
        case id, text, users
        case postId = "post_id"
        case userId = "user_id"
        case createdAt = "created_at"
        case parentCommentId = "parent_comment_id"
        case commentLikes = "comment_likes"
    }
}

// Codable struct matching the Supabase 'feed' view
struct SupabaseFeedPost: Codable {
    let id: UUID
    let note: String?
    let createdAt: Date
    let userId: UUID
    let userName: String
    let username: String
    let profileImageUrl: String?
    let restaurantId: UUID
    let restaurantName: String
    let cuisine: String?
    let location: String?
    let rating: Double?
    let priceLevel: Int?
    let imageUrl: String?
    let imageUrls: [String]?
    let likeCount: Int
    let commentCount: Int
    let vibeTags: [String]?

    enum CodingKeys: String, CodingKey {
        case id, note, username, cuisine, location, rating
        case createdAt = "created_at"
        case userId = "user_id"
        case userName = "user_name"
        case profileImageUrl = "profile_image_url"
        case restaurantId = "restaurant_id"
        case restaurantName = "restaurant_name"
        case priceLevel = "price_level"
        case imageUrl = "image_url"
        case imageUrls = "image_urls"
        case likeCount = "like_count"
        case commentCount = "comment_count"
        case vibeTags = "vibe_tags"
    }

    func toRecommendation() -> Recommendation {
        var user = User(
            name: userName,
            username: username,
            profileImageURL: profileImageUrl ?? "",
            followersCount: 0,
            followingCount: 0
        )
        user.id = userId

        var restaurant = Restaurant(
            name: restaurantName,
            cuisine: cuisine ?? "",
            location: location ?? "",
            imageURL: imageUrl ?? "",
            rating: rating ?? 0,
            priceLevel: priceLevel ?? 1,
            description: ""
        )
        restaurant.id = restaurantId

        var rec = Recommendation(
            restaurant: restaurant,
            user: user,
            note: note ?? "",
            date: createdAt,
            isSaved: false,
            vibeTags: vibeTags ?? []
        )
        rec.id = id
        rec.imageURLs = imageUrls ?? []
        return rec
    }
}

// Sample data for preview/development
extension Restaurant {
    static let sample1 = Restaurant(
        name: "Marea",
        cuisine: "Italian",
        location: "New York, NY",
        imageURL: "restaurant1",
        rating: 4.7,
        priceLevel: 4,
        description: "Upscale Italian seafood restaurant with a focus on crudo and housemade pastas."
    )
    
    static let sample2 = Restaurant(
        name: "Lilia",
        cuisine: "Italian",
        location: "Brooklyn, NY",
        imageURL: "restaurant2",
        rating: 4.6,
        priceLevel: 3,
        description: "Wood-fired Italian food with fresh pasta made in-house daily."
    )
    
    static let sample3 = Restaurant(
        name: "Don Angie",
        cuisine: "Italian-American",
        location: "New York, NY",
        imageURL: "restaurant3",
        rating: 4.5,
        priceLevel: 3,
        description: "Italian-American food with creative twists on classic dishes."
    )
    
    static let samples = [sample1, sample2, sample3]
}

extension User {
    static let sarah = User(
        name: "Sarah Chen",
        username: "@sarahchen",
        profileImageURL: "profile1",
        followersCount: 234,
        followingCount: 189
    )
    
    static let marcus = User(
        name: "Marcus Williams",
        username: "@marcusw",
        profileImageURL: "profile2",
        followersCount: 456,
        followingCount: 321
    )
    
    static let samples = [sarah, marcus]
}

extension Recommendation {
    static let sample1 = Recommendation(
        restaurant: Restaurant.sample1,
        user: User.sarah,
        note: "Best pasta I've had in NYC! The fusilli is a must-try.",
        date: Date().addingTimeInterval(-86400),
        isSaved: false
    )
    
    static let sample2 = Recommendation(
        restaurant: Restaurant.sample2,
        user: User.marcus,
        note: "Amazing wood-fired dishes. Get there early or expect a wait!",
        date: Date().addingTimeInterval(-172800),
        isSaved: true
    )
    
    static let sample3 = Recommendation(
        restaurant: Restaurant.sample3,
        user: User.sarah,
        note: "The lasagna for two is incredible. Book ahead!",
        date: Date().addingTimeInterval(-259200),
        isSaved: false
    )
    
    static let samples = [sample1, sample2, sample3]
}
// Tracks which posts the current user has already seen — via dwell
// in the feed (~2s on screen), tapping into comments / the image
// viewer, or engaging with the like / save buttons. Seen posts drop
// to the bottom of the feed so the user sees fresh recommendations
// first; once the unseen queue is empty, seen posts come back.
@Observable
class PostViewsManager {
    var viewedPostIds: Set<UUID> = []

    func load(userId: UUID) async {
        struct Row: Decodable {
            let postId: UUID
            enum CodingKeys: String, CodingKey { case postId = "post_id" }
        }
        do {
            let rows: [Row] = try await supabase
                .from("post_views")
                .select("post_id")
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value
            viewedPostIds = Set(rows.map(\.postId))
        } catch {
            debugLog("Post views fetch error", error)
        }
    }

    /// Idempotent — re-marking a post that's already in the set is a
    /// no-op locally and an upsert server-side (ignore on conflict),
    /// so the dwell-timer firing alongside an engagement tap doesn't
    /// generate duplicate writes.
    func markViewed(_ postId: UUID, by userId: UUID) {
        guard !viewedPostIds.contains(postId) else { return }
        viewedPostIds.insert(postId)
        Task { @MainActor in
            struct ViewRow: Encodable {
                let user_id: String
                let post_id: String
            }
            do {
                try await supabase.from("post_views")
                    .upsert(
                        ViewRow(
                            user_id: userId.uuidString,
                            post_id: postId.uuidString
                        ),
                        onConflict: "user_id,post_id",
                        ignoreDuplicates: true
                    )
                    .execute()
            } catch {
                debugLog("Post view insert error", error)
            }
        }
    }
}

// Observable class to manage the feed recommendations across the app
@Observable
class RecommendationsManager {
    var recommendations: [Recommendation] = []
    var isLoading = false

    func fetchFeed(
        likesManager: LikesManager? = nil,
        commentsManager: CommentsManager? = nil,
        postViewsManager: PostViewsManager? = nil,
        followManager: FollowManager? = nil
    ) async {
        isLoading = true
        do {
            // Cap the initial payload — at 1k+ posts the full table
            // was slow to transfer + decode on device. The client can
            // always pull-to-refresh for the newest 200.
            let posts: [SupabaseFeedPost] = try await supabase
                .from("feed")
                .select()
                .order("created_at", ascending: false)
                .limit(200)
                .execute()
                .value

            // Three-tier sort, chronological desc within each tier.
            // Top: unseen AND liked by someone you follow.
            // Middle: unseen.
            // Bottom: seen (fallback so the feed never goes blank).
            // Follow-weighted elevation is temporarily disabled — the
            // .in() filter on a large followed-user set was tanking
            // the feed load. Re-add once we have a dedicated endpoint
            // that returns just the post-id set.
            // A liked post counts as seen — once you've engaged with it
            // we don't want it back in the unseen queue. Covers historical
            // likes that pre-date the post_views table too.
            var seen = postViewsManager?.viewedPostIds ?? []
            if let liked = likesManager?.likedRecommendations {
                seen.formUnion(liked)
            }
            let socialPostIds: Set<UUID> = []
            _ = followManager // silence unused-parameter warning
            func tier(_ post: SupabaseFeedPost) -> Int {
                if seen.contains(post.id) { return 2 }
                if socialPostIds.contains(post.id) { return 0 }
                return 1
            }
            let ordered = posts.sorted { a, b in
                let ta = tier(a); let tb = tier(b)
                if ta != tb { return ta < tb }
                return a.createdAt > b.createdAt
            }
            recommendations = ordered.map { $0.toRecommendation() }
            likesManager?.hydrate(from: posts)
            // Just hydrate the counts off the feed view — actual comment
            // bodies are fetched lazily per-post when a user opens the
            // sheet. Pulling every comment row up front got unworkable
            // once the seeded test data crossed ~50k comments.
            commentsManager?.hydrateCounts(from: posts)
        } catch {
            debugLog("Feed fetch error", error)
        }
        isLoading = false
    }

    func addRecommendation(_ recommendation: Recommendation) {
        recommendations.insert(recommendation, at: 0)
    }

    /// Inserts a new post into Supabase on behalf of the authenticated user.
    /// The server enforces `auth.uid() = user_id` via RLS, so the `user_id`
    /// we pass must match the current session. Optimistically prepends the
    /// post to the local feed and rolls back on failure.
    func createPost(
        restaurant: Restaurant,
        note: String,
        user: User,
        vibeTags: [String] = [],
        imageUrls: [String] = []
    ) async throws {
        struct NewPost: Encodable {
            let user_id: String
            let restaurant_id: String
            let note: String
            let vibe_tags: [String]
            let image_urls: [String]
        }
        let normalizedTags = Array(Set(vibeTags.map(Vibe.normalize))).filter { !$0.isEmpty }
        let payload = NewPost(
            user_id: user.id.uuidString,
            restaurant_id: restaurant.id.uuidString,
            note: note,
            vibe_tags: normalizedTags,
            image_urls: imageUrls
        )
        // Use the first uploaded image (if any) as the optimistic cover
        // so the card doesn't show the restaurant's blank placeholder
        // while the feed re-fetches.
        let optimisticRestaurant: Restaurant = {
            guard let firstImage = imageUrls.first, !firstImage.isEmpty,
                  restaurant.imageURL.isEmpty else { return restaurant }
            var copy = Restaurant(
                name: restaurant.name,
                cuisine: restaurant.cuisine,
                location: restaurant.location,
                imageURL: firstImage,
                rating: restaurant.rating,
                priceLevel: restaurant.priceLevel,
                description: restaurant.description
            )
            copy.id = restaurant.id
            return copy
        }()
        var optimistic = Recommendation(
            restaurant: optimisticRestaurant,
            user: user,
            note: note,
            date: Date(),
            isSaved: false,
            vibeTags: normalizedTags
        )
        optimistic.imageURLs = imageUrls
        recommendations.insert(optimistic, at: 0)
        do {
            try await supabase.from("posts").insert(payload).execute()
        } catch {
            recommendations.removeAll { $0.id == optimistic.id }
            throw error
        }
    }
}

// Observable class to manage saved restaurants across the app.
// Hydrates from `saved_restaurants` on sign-in and persists toggles
// back to Supabase (previously all state was local and evaporated on
// every cold launch).
@Observable
class SavedRestaurantsManager {
    var savedRestaurants: [Restaurant] = []
    /// Set when a toggle's network round-trip fails. Surfaced to the
    /// user as a banner so silent RLS / FK / network errors stop
    /// looking like a no-op bookmark tap.
    var lastError: String?

    func isSaved(_ restaurant: Restaurant) -> Bool {
        savedRestaurants.contains { $0.id == restaurant.id }
    }

    func loadSaved(userId: UUID) async {
        struct SavedRow: Decodable {
            let restaurants: RestaurantPayload
            struct RestaurantPayload: Decodable {
                let id: UUID
                let name: String
                let cuisine: String?
                let location: String?
                let rating: Double?
                let priceLevel: Int?
                let imageUrl: String?
                let description: String?
                enum CodingKeys: String, CodingKey {
                    case id, name, cuisine, location, rating, description
                    case priceLevel = "price_level"
                    case imageUrl = "image_url"
                }
            }
        }
        do {
            let rows: [SavedRow] = try await supabase
                .from("saved_restaurants")
                .select("restaurants(id, name, cuisine, location, rating, price_level, image_url, description)")
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value
            savedRestaurants = rows.map { row in
                var r = Restaurant(
                    name: row.restaurants.name,
                    cuisine: row.restaurants.cuisine ?? "",
                    location: row.restaurants.location ?? "",
                    imageURL: row.restaurants.imageUrl ?? "",
                    rating: row.restaurants.rating ?? 0,
                    priceLevel: row.restaurants.priceLevel ?? 1,
                    description: row.restaurants.description ?? ""
                )
                r.id = row.restaurants.id
                return r
            }
        } catch {
            debugLog("Saved restaurants fetch error", error)
        }
    }

    /// Optimistically flips the local state, persists to Supabase, and
    /// reverts on failure. `userId` must be the session user — RLS
    /// enforces `auth.uid() = user_id`.
    func toggleSave(_ restaurant: Restaurant, by userId: UUID) {
        let wasSaved = isSaved(restaurant)
        if wasSaved {
            savedRestaurants.removeAll { $0.id == restaurant.id }
        } else {
            savedRestaurants.append(restaurant)
        }
        let restaurantId = restaurant.id
        Task { @MainActor in
            do {
                if wasSaved {
                    try await supabase.from("saved_restaurants")
                        .delete()
                        .eq("user_id", value: userId.uuidString)
                        .eq("restaurant_id", value: restaurantId.uuidString)
                        .execute()
                } else {
                    struct SaveRow: Encodable {
                        let user_id: String
                        let restaurant_id: String
                    }
                    // Upsert (not insert) so a stale local state that
                    // already had the row server-side doesn't fail the
                    // composite-PK INSERT and revert the optimistic add.
                    try await supabase.from("saved_restaurants")
                        .upsert(
                            SaveRow(
                                user_id: userId.uuidString,
                                restaurant_id: restaurantId.uuidString
                            ),
                            onConflict: "user_id,restaurant_id"
                        )
                        .execute()
                }
                lastError = nil
            } catch {
                debugLog("Save toggle error", error)
                lastError = friendlyMessage(for: error, action: wasSaved ? "remove" : "save")
                if wasSaved {
                    self.savedRestaurants.append(restaurant)
                } else {
                    self.savedRestaurants.removeAll { $0.id == restaurantId }
                }
            }
        }
    }

    private func friendlyMessage(for error: Error, action: String) -> String {
        let raw = String(describing: error)
        if raw.contains("row-level security") || raw.contains("42501") {
            return "Couldn't \(action) — auth check failed. Try signing out and back in."
        }
        if raw.contains("foreign key") || raw.contains("23503") {
            // saved_restaurants has FKs on both user_id and restaurant_id;
            // by far the more common cause is a missing public.users row
            // for an Apple sign-in tester whose profile-row trigger
            // didn't fire. Sign out / back in self-heals.
            return "Couldn't \(action) — profile not synced. Sign out and back in to fix."
        }
        if raw.contains("network") || raw.contains("offline") || raw.contains("connection") {
            return "Couldn't \(action) — no internet."
        }
        return "Couldn't \(action) bookmark. \(error.localizedDescription)"
    }
}

// Observable class to manage likes across the app
@Observable
class LikesManager {
    var likedRecommendations: Set<UUID> = []
    var likeCounts: [UUID: Int] = [:]

    func hydrate(from posts: [SupabaseFeedPost]) {
        for post in posts {
            likeCounts[post.id] = post.likeCount
        }
    }

    /// Loads the set of posts the current user has already liked so the
    /// hearts render filled on cold launch. Without this, a relaunched
    /// user sees an empty heart on posts they've liked before — and
    /// tapping triggers a duplicate INSERT against the (user_id, post_id)
    /// primary key, which the server rejects and the catch-block reverts,
    /// producing the "tap flashes but doesn't stick" behavior.
    func loadLiked(userId: UUID) async {
        struct LikeRow: Decodable {
            let postId: UUID
            enum CodingKeys: String, CodingKey {
                case postId = "post_id"
            }
        }
        do {
            let rows: [LikeRow] = try await supabase
                .from("likes")
                .select("post_id")
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value
            likedRecommendations = Set(rows.map(\.postId))
        } catch {
            debugLog("Liked posts fetch error", error)
        }
    }

    func isLiked(_ recommendation: Recommendation) -> Bool {
        likedRecommendations.contains(recommendation.id)
    }
    
    /// Toggles the like state locally for immediate UI feedback, then
    /// persists the change to Supabase on behalf of the authenticated user.
    /// Reverts the optimistic update if the server call fails.
    /// `userId` must be the session user — RLS enforces `auth.uid() = user_id`.
    func toggleLike(_ recommendation: Recommendation, by userId: UUID) {
        let wasLiked = likedRecommendations.contains(recommendation.id)
        if wasLiked {
            likedRecommendations.remove(recommendation.id)
            likeCounts[recommendation.id, default: 0] -= 1
        } else {
            likedRecommendations.insert(recommendation.id)
            likeCounts[recommendation.id, default: 0] += 1
        }
        let postId = recommendation.id
        Task { @MainActor in
            do {
                if wasLiked {
                    try await supabase.from("likes")
                        .delete()
                        .eq("user_id", value: userId.uuidString)
                        .eq("post_id", value: postId.uuidString)
                        .execute()
                } else {
                    struct LikeRow: Encodable {
                        let user_id: String
                        let post_id: String
                    }
                    try await supabase.from("likes")
                        .insert(LikeRow(user_id: userId.uuidString, post_id: postId.uuidString))
                        .execute()
                }
            } catch {
                debugLog("Like toggle error", error)
                if wasLiked {
                    self.likedRecommendations.insert(postId)
                    self.likeCounts[postId, default: 0] += 1
                } else {
                    self.likedRecommendations.remove(postId)
                    self.likeCounts[postId, default: 0] -= 1
                }
            }
        }
    }
    
    func likeCount(for recommendation: Recommendation) -> Int {
        likeCounts[recommendation.id, default: 0]
    }
}

// Observable class to manage comments across the app
@Observable
class CommentsManager {
    var comments: [UUID: [Comment]] = [:]
    var serverCommentCounts: [UUID: Int] = [:]
    var commentLikes: [UUID: Set<UUID>] = [:] // commentId: Set of user IDs who liked it

    func hydrateCounts(from posts: [SupabaseFeedPost]) {
        for post in posts {
            serverCommentCounts[post.id] = post.commentCount
        }
    }

    func fetchAllComments() async {
        // Kept for tests / batch refresh — production paths fetch one post at
        // a time via `fetchComments(for:)` to avoid pulling the entire
        // comments table every time a sheet opens.
        do {
            let rows: [SupabaseComment] = try await supabase
                .from("comments")
                .select("id, post_id, user_id, text, created_at, parent_comment_id, users!comments_user_id_fkey(name, username, profile_image_url), comment_likes(user_id)")
                .order("created_at", ascending: false)
                .execute()
                .value
            mergeComments(rows: rows, replacePostIds: Set(rows.map(\.postId)))
        } catch {
            debugLog("Comments fetch error", "\(error.localizedDescription) | \(error)")
        }
    }

    /// Loads comments for a single post. Merges into the existing in-memory
    /// dictionary so previously-fetched posts stay cached.
    func fetchComments(for postId: UUID) async {
        do {
            let rows: [SupabaseComment] = try await supabase
                .from("comments")
                .select("id, post_id, user_id, text, created_at, parent_comment_id, users!comments_user_id_fkey(name, username, profile_image_url), comment_likes(user_id)")
                .eq("post_id", value: postId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value
            mergeComments(rows: rows, replacePostIds: [postId])
        } catch {
            debugLog("Comments fetch error", "\(error.localizedDescription) | \(error)")
        }
    }

    private func mergeComments(rows: [SupabaseComment], replacePostIds: Set<UUID>) {
        // Wipe slates for the posts we just refetched so we don't leave
        // stale comments around (e.g. one was deleted server-side).
        for postId in replacePostIds {
            comments[postId] = []
        }
        var likesPatch: [UUID: Set<UUID>] = [:]
        for row in rows {
            var user = User(
                name: row.users.name,
                username: row.users.username,
                profileImageURL: row.users.profileImageUrl ?? "",
                followersCount: 0,
                followingCount: 0
            )
            user.id = row.userId
            let likers = Set((row.commentLikes ?? []).map(\.userId))
            var comment = Comment(
                user: user,
                text: row.text,
                date: row.createdAt,
                likeCount: likers.count
            )
            comment.id = row.id
            comment.parentCommentId = row.parentCommentId
            comments[row.postId, default: []].append(comment)
            if !likers.isEmpty {
                likesPatch[comment.id] = likers
            }
        }
        for (commentId, likers) in likesPatch {
            commentLikes[commentId] = likers
        }
        for postId in replacePostIds {
            let count = comments[postId]?.count ?? 0
            serverCommentCounts[postId] = max(serverCommentCounts[postId, default: 0], count)
        }
    }

    /// Returns only top-level comments (no parent) for a post, sorted by
    /// like count then recency. Replies are fetched separately via
    /// `getReplies(to:in:)`.
    func getTopLevelComments(for recommendation: Recommendation) -> [Comment] {
        comments[recommendation.id, default: []]
            .filter { $0.parentCommentId == nil }
            .sorted { a, b in
                if a.likeCount != b.likeCount { return a.likeCount > b.likeCount }
                return a.date > b.date
            }
    }

    /// Returns replies to a specific parent comment on a specific post,
    /// in chronological order (oldest first).
    func getReplies(to parentId: UUID, in recommendation: Recommendation) -> [Comment] {
        comments[recommendation.id, default: []]
            .filter { $0.parentCommentId == parentId }
            .sorted { $0.date < $1.date }
    }

    func replyCount(to parentId: UUID, in recommendation: Recommendation) -> Int {
        comments[recommendation.id, default: []]
            .filter { $0.parentCommentId == parentId }
            .count
    }

    func getComments(for recommendation: Recommendation) -> [Comment] {
        let allComments = comments[recommendation.id, default: []]
        // Sort by like count (descending), then by date (most recent first)
        return allComments.sorted { comment1, comment2 in
            if comment1.likeCount != comment2.likeCount {
                return comment1.likeCount > comment2.likeCount
            }
            return comment1.date > comment2.date
        }
    }
    
    func getTopComments(for recommendation: Recommendation, limit: Int = 3) -> [Comment] {
        let sorted = getComments(for: recommendation)
        return Array(sorted.prefix(limit))
    }
    
    /// Appends a comment locally for immediate UI feedback, then persists
    /// it to Supabase. The `user` must be the authenticated session user —
    /// RLS enforces `auth.uid() = user_id`. Pass `parentCommentId` to make
    /// the new row a reply. Reverts on failure.
    func addComment(
        _ text: String,
        to recommendation: Recommendation,
        by user: User,
        parentCommentId: UUID? = nil
    ) {
        var comment = Comment(user: user, text: text, date: Date(), likeCount: 0)
        comment.parentCommentId = parentCommentId
        comments[recommendation.id, default: []].append(comment)
        serverCommentCounts[recommendation.id, default: 0] += 1
        let postId = recommendation.id
        let commentId = comment.id
        Task { @MainActor in
            do {
                // Send the client-generated id so the server row shares
                // the same UUID we're rendering locally. Without this,
                // replying to your own just-posted comment fails: the
                // reply's `parent_comment_id` points at the optimistic
                // UUID, but the server stored a different
                // gen_random_uuid() — the FK lookup misses and the
                // insert is rejected.
                struct NewComment: Encodable {
                    let id: String
                    let post_id: String
                    let user_id: String
                    let text: String
                    let parent_comment_id: String?
                }
                try await supabase.from("comments")
                    .insert(NewComment(
                        id: commentId.uuidString,
                        post_id: postId.uuidString,
                        user_id: user.id.uuidString,
                        text: text,
                        parent_comment_id: parentCommentId?.uuidString
                    ))
                    .execute()
            } catch {
                debugLog("Comment insert error", error)
                if var list = self.comments[postId] {
                    list.removeAll { $0.id == commentId }
                    self.comments[postId] = list
                }
                self.serverCommentCounts[postId, default: 1] -= 1
            }
        }
    }
    
    func commentCount(for recommendation: Recommendation) -> Int {
        max(comments[recommendation.id, default: []].count, serverCommentCounts[recommendation.id, default: 0])
    }
    
    func isCommentLiked(_ comment: Comment, by userId: UUID) -> Bool {
        commentLikes[comment.id, default: []].contains(userId)
    }
    
    /// Optimistically flips the like locally, persists to Supabase, and
    /// reverts on failure. `userId` must be the session user — RLS
    /// enforces `auth.uid() = user_id`.
    func toggleCommentLike(_ comment: Comment, by userId: UUID) {
        let wasLiked = commentLikes[comment.id, default: []].contains(userId)
        if wasLiked {
            commentLikes[comment.id]?.remove(userId)
            updateCommentLikeCount(comment.id, delta: -1)
        } else {
            commentLikes[comment.id, default: []].insert(userId)
            updateCommentLikeCount(comment.id, delta: 1)
        }
        let commentId = comment.id
        Task { @MainActor in
            do {
                if wasLiked {
                    try await supabase.from("comment_likes")
                        .delete()
                        .eq("user_id", value: userId.uuidString)
                        .eq("comment_id", value: commentId.uuidString)
                        .execute()
                } else {
                    struct LikeRow: Encodable {
                        let user_id: String
                        let comment_id: String
                    }
                    try await supabase.from("comment_likes")
                        .insert(LikeRow(
                            user_id: userId.uuidString,
                            comment_id: commentId.uuidString
                        ))
                        .execute()
                }
            } catch {
                debugLog("Comment like toggle error", error)
                if wasLiked {
                    self.commentLikes[commentId, default: []].insert(userId)
                    self.updateCommentLikeCount(commentId, delta: 1)
                } else {
                    self.commentLikes[commentId]?.remove(userId)
                    self.updateCommentLikeCount(commentId, delta: -1)
                }
            }
        }
    }

    private func updateCommentLikeCount(_ commentId: UUID, delta: Int) {
        for (recommendationId, var commentsList) in comments {
            if let index = commentsList.firstIndex(where: { $0.id == commentId }) {
                commentsList[index].likeCount += delta
                comments[recommendationId] = commentsList
                return
            }
        }
    }
    
    func getCommentLikeCount(_ comment: Comment) -> Int {
        commentLikes[comment.id, default: []].count
    }
}

// Observable class to manage follows across the app. Hydrates the
// set of users the session user follows from `follows` on sign-in
// and persists toggles back to Supabase (previously toggles never
// reached the DB, so the feed was never actually personalized).
@Observable
class FollowManager {
    var followedUsers: Set<UUID> = []

    func isFollowing(_ user: User) -> Bool {
        followedUsers.contains(user.id)
    }

    func loadFollowing(userId: UUID) async {
        struct FollowRow: Decodable {
            let followingId: UUID
            enum CodingKeys: String, CodingKey {
                case followingId = "following_id"
            }
        }
        do {
            let rows: [FollowRow] = try await supabase
                .from("follows")
                .select("following_id")
                .eq("follower_id", value: userId.uuidString)
                .execute()
                .value
            followedUsers = Set(rows.map(\.followingId))
        } catch {
            debugLog("Following fetch error", error)
        }
    }

    /// Optimistically flips local state, persists to Supabase, reverts
    /// on failure. `followerId` must be the session user — RLS enforces
    /// `auth.uid() = follower_id`.
    func toggleFollow(_ user: User, by followerId: UUID) {
        let wasFollowing = followedUsers.contains(user.id)
        if wasFollowing {
            followedUsers.remove(user.id)
        } else {
            followedUsers.insert(user.id)
        }
        let targetId = user.id
        Task { @MainActor in
            do {
                if wasFollowing {
                    try await supabase.from("follows")
                        .delete()
                        .eq("follower_id", value: followerId.uuidString)
                        .eq("following_id", value: targetId.uuidString)
                        .execute()
                } else {
                    struct FollowRow: Encodable {
                        let follower_id: String
                        let following_id: String
                    }
                    try await supabase.from("follows")
                        .insert(FollowRow(
                            follower_id: followerId.uuidString,
                            following_id: targetId.uuidString
                        ))
                        .execute()
                }
            } catch {
                debugLog("Follow toggle error", error)
                if wasFollowing {
                    self.followedUsers.insert(targetId)
                } else {
                    self.followedUsers.remove(targetId)
                }
            }
        }
    }
}
