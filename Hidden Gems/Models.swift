//
//  Models.swift
//  Hidden Gems
//
//  Created by Divine Davis on 3/16/26.
//

import Foundation

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

struct User: Identifiable {
    let id = UUID()
    let name: String
    let username: String
    let profileImageURL: String
    let followersCount: Int
    let followingCount: Int
}

// Sample data for preview/development
extension Restaurant {
    static let samples = [
        Restaurant(
            name: "Marea",
            cuisine: "Italian",
            location: "New York, NY",
            imageURL: "restaurant1",
            rating: 4.7,
            priceLevel: 4,
            description: "Upscale Italian seafood restaurant with a focus on crudo and housemade pastas."
        ),
        Restaurant(
            name: "Lilia",
            cuisine: "Italian",
            location: "Brooklyn, NY",
            imageURL: "restaurant2",
            rating: 4.6,
            priceLevel: 3,
            description: "Wood-fired Italian food with fresh pasta made in-house daily."
        ),
        Restaurant(
            name: "Don Angie",
            cuisine: "Italian-American",
            location: "New York, NY",
            imageURL: "restaurant3",
            rating: 4.5,
            priceLevel: 3,
            description: "Italian-American food with creative twists on classic dishes."
        )
    ]
}

extension User {
    static let samples = [
        User(
            name: "Sarah Chen",
            username: "@sarahchen",
            profileImageURL: "profile1",
            followersCount: 234,
            followingCount: 189
        ),
        User(
            name: "Marcus Williams",
            username: "@marcusw",
            profileImageURL: "profile2",
            followersCount: 456,
            followingCount: 321
        )
    ]
}

extension Recommendation {
    static let samples = [
        Recommendation(
            restaurant: Restaurant.samples[0],
            user: User.samples[0],
            note: "Best pasta I've had in NYC! The fusilli is a must-try.",
            date: Date().addingTimeInterval(-86400),
            isSaved: false
        ),
        Recommendation(
            restaurant: Restaurant.samples[1],
            user: User.samples[1],
            note: "Amazing wood-fired dishes. Get there early or expect a wait!",
            date: Date().addingTimeInterval(-172800),
            isSaved: true
        ),
        Recommendation(
            restaurant: Restaurant.samples[2],
            user: User.samples[0],
            note: "The lasagna for two is incredible. Book ahead!",
            date: Date().addingTimeInterval(-259200),
            isSaved: false
        )
    ]
}
