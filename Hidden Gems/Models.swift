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
}

struct Recommendation: Identifiable {
    var id: UUID = UUID()
    let restaurant: Restaurant
    let user: User
    let note: String
    let date: Date
    let isSaved: Bool
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
    let profileImageURL: String
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
// joined with the user who wrote the comment.
struct SupabaseComment: Codable {
    let id: UUID
    let postId: UUID
    let userId: UUID
    let text: String
    let createdAt: Date
    let parentCommentId: UUID?
    let users: Author

    struct Author: Codable {
        let name: String
        let username: String
        let profileImageUrl: String?

        enum CodingKeys: String, CodingKey {
            case name, username
            case profileImageUrl = "profile_image_url"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, text, users
        case postId = "post_id"
        case userId = "user_id"
        case createdAt = "created_at"
        case parentCommentId = "parent_comment_id"
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
    let likeCount: Int
    let commentCount: Int

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
        case likeCount = "like_count"
        case commentCount = "comment_count"
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
            isSaved: false
        )
        rec.id = id
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
// Observable class to manage the feed recommendations across the app
@Observable
class RecommendationsManager {
    var recommendations: [Recommendation] = []
    var isLoading = false

    func fetchFeed(likesManager: LikesManager? = nil, commentsManager: CommentsManager? = nil) async {
        isLoading = true
        do {
            let posts: [SupabaseFeedPost] = try await supabase
                .from("feed")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            recommendations = posts.map { $0.toRecommendation() }
            likesManager?.hydrate(from: posts)
            commentsManager?.hydrateCounts(from: posts)
            if let commentsManager {
                await commentsManager.fetchAllComments()
            }
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
    func createPost(restaurant: Restaurant, note: String, user: User) async throws {
        struct NewPost: Encodable {
            let user_id: String
            let restaurant_id: String
            let note: String
        }
        let payload = NewPost(
            user_id: user.id.uuidString,
            restaurant_id: restaurant.id.uuidString,
            note: note
        )
        var optimistic = Recommendation(
            restaurant: restaurant,
            user: user,
            note: note,
            date: Date(),
            isSaved: false
        )
        recommendations.insert(optimistic, at: 0)
        do {
            try await supabase.from("posts").insert(payload).execute()
        } catch {
            recommendations.removeAll { $0.id == optimistic.id }
            throw error
        }
    }
}

// Observable class to manage saved restaurants across the app
@Observable
class SavedRestaurantsManager {
    var savedRestaurants: [Restaurant] = []
    
    func isSaved(_ restaurant: Restaurant) -> Bool {
        savedRestaurants.contains { $0.id == restaurant.id }
    }
    
    func toggleSave(_ restaurant: Restaurant) {
        if let index = savedRestaurants.firstIndex(where: { $0.id == restaurant.id }) {
            savedRestaurants.remove(at: index)
        } else {
            savedRestaurants.append(restaurant)
        }
    }
    
    func save(_ restaurant: Restaurant) {
        if !isSaved(restaurant) {
            savedRestaurants.append(restaurant)
        }
    }
    
    func unsave(_ restaurant: Restaurant) {
        savedRestaurants.removeAll { $0.id == restaurant.id }
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
        do {
            let rows: [SupabaseComment] = try await supabase
                .from("comments")
                .select("id, post_id, user_id, text, created_at, parent_comment_id, users(name, username, profile_image_url)")
                .order("created_at", ascending: false)
                .execute()
                .value
            var grouped: [UUID: [Comment]] = [:]
            for row in rows {
                var user = User(
                    name: row.users.name,
                    username: row.users.username,
                    profileImageURL: row.users.profileImageUrl ?? "",
                    followersCount: 0,
                    followingCount: 0
                )
                user.id = row.userId
                var comment = Comment(user: user, text: row.text, date: row.createdAt, likeCount: 0)
                comment.id = row.id
                comment.parentCommentId = row.parentCommentId
                grouped[row.postId, default: []].append(comment)
            }
            comments = grouped
            for (postId, list) in grouped {
                serverCommentCounts[postId] = max(serverCommentCounts[postId, default: 0], list.count)
            }
        } catch {
            debugLog("Comments fetch error", "\(error.localizedDescription) | \(error)")
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
                struct NewComment: Encodable {
                    let post_id: String
                    let user_id: String
                    let text: String
                    let parent_comment_id: String?
                }
                try await supabase.from("comments")
                    .insert(NewComment(
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
    
    func toggleCommentLike(_ comment: Comment, by userId: UUID) {
        if commentLikes[comment.id, default: []].contains(userId) {
            // Unlike
            commentLikes[comment.id]?.remove(userId)
            updateCommentLikeCount(comment, increment: false)
        } else {
            // Like
            commentLikes[comment.id, default: []].insert(userId)
            updateCommentLikeCount(comment, increment: true)
        }
    }
    
    private func updateCommentLikeCount(_ comment: Comment, increment: Bool) {
        // Find and update the comment in all recommendations
        for (recommendationId, var commentsList) in comments {
            if let index = commentsList.firstIndex(where: { $0.id == comment.id }) {
                commentsList[index].likeCount += increment ? 1 : -1
                comments[recommendationId] = commentsList
                break
            }
        }
    }
    
    func getCommentLikeCount(_ comment: Comment) -> Int {
        commentLikes[comment.id, default: []].count
    }
}

// Observable class to manage follows across the app
@Observable
class FollowManager {
    var followedUsers: Set<UUID> = []
    // Placeholder until the view hydrates this from authManager.currentUser.
    // Kept as an empty User so no sample data leaks into live code paths.
    var currentUser: User = User(
        name: "",
        username: "",
        profileImageURL: "",
        followersCount: 0,
        followingCount: 0
    )

    func isFollowing(_ user: User) -> Bool {
        followedUsers.contains(user.id)
    }

    func toggleFollow(_ user: User) {
        if followedUsers.contains(user.id) {
            followedUsers.remove(user.id)
        } else {
            followedUsers.insert(user.id)
        }
    }
}
