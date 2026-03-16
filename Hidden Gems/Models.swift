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
    // UUID set for O(1) membership checks
    private var savedIDs: Set<UUID> = []

    func isSaved(_ restaurant: Restaurant) -> Bool {
        savedIDs.contains(restaurant.id)
    }

    func toggleSave(_ restaurant: Restaurant) {
        if savedIDs.contains(restaurant.id) {
            unsave(restaurant)
        } else {
            save(restaurant)
        }
    }

    func save(_ restaurant: Restaurant) {
        guard !savedIDs.contains(restaurant.id) else { return }
        savedRestaurants.append(restaurant)
        savedIDs.insert(restaurant.id)
    }

    func unsave(_ restaurant: Restaurant) {
        savedRestaurants.removeAll { $0.id == restaurant.id }
        savedIDs.remove(restaurant.id)
    }
}

// Observable class to manage likes across the app
@Observable
class LikesManager {
    // One like per user — count is always 0 or 1, derived from set membership
    private var likedIDs: Set<UUID> = []

    func isLiked(_ recommendation: Recommendation) -> Bool {
        likedIDs.contains(recommendation.id)
    }

    func toggleLike(_ recommendation: Recommendation) {
        if likedIDs.contains(recommendation.id) {
            likedIDs.remove(recommendation.id)
        } else {
            likedIDs.insert(recommendation.id)
        }
    }

    func likeCount(for recommendation: Recommendation) -> Int {
        likedIDs.contains(recommendation.id) ? 1 : 0
    }
}

// Observable class to manage follows across the app
@Observable
class FollowManager {
    var followedUsers: Set<UUID> = []
    // The logged-in user — single source of truth shared across the app
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

