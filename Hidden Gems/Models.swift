//
//  Models.swift
//  Hidden Gems
//
//  Created by Divine Davis on 3/16/26.
//

import Foundation
import SwiftUI

struct Restaurant: Identifiable {
    let id = UUID()
    let name: String
    let cuisine: String
    let location: String
    let imageURL: String
    let rating: Double
    let priceLevel: Int // 1-4 ($-$$$$)
    let description: String
}

struct Recommendation: Identifiable {
    let id = UUID()
    let restaurant: Restaurant
    let user: User
    let note: String
    let date: Date
    let isSaved: Bool
}

struct Comment: Identifiable, Equatable {
    let id = UUID()
    let user: User
    let text: String
    let date: Date
    var likeCount: Int = 0
    
    static func == (lhs: Comment, rhs: Comment) -> Bool {
        lhs.id == rhs.id
    }
}

struct User: Identifiable, Equatable, Hashable {
    let id = UUID()
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
    
    func isLiked(_ recommendation: Recommendation) -> Bool {
        likedRecommendations.contains(recommendation.id)
    }
    
    func toggleLike(_ recommendation: Recommendation) {
        if likedRecommendations.contains(recommendation.id) {
            likedRecommendations.remove(recommendation.id)
            likeCounts[recommendation.id, default: 0] -= 1
        } else {
            likedRecommendations.insert(recommendation.id)
            likeCounts[recommendation.id, default: 0] += 1
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
    var commentLikes: [UUID: Set<UUID>] = [:] // commentId: Set of user IDs who liked it
    
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
    
    func addComment(_ text: String, to recommendation: Recommendation, by user: User) {
        let comment = Comment(user: user, text: text, date: Date(), likeCount: 0)
        comments[recommendation.id, default: []].append(comment)
    }
    
    func commentCount(for recommendation: Recommendation) -> Int {
        comments[recommendation.id, default: []].count
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
    var currentUser: User = User.sarah

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
