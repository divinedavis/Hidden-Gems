//
//  SharedComponents.swift
//  Hidden Gems
//
//  Created by Divine Davis on 3/16/26.
//

import SwiftUI

/// Cuisine, price level, and location rows for a restaurant.
struct RestaurantMetaInfo: View {
    let restaurant: Restaurant

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(restaurant.cuisine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("•")
                    .foregroundStyle(.secondary)
                Text(String(repeating: "$", count: restaurant.priceLevel))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 4) {
                Image(systemName: "mappin.circle.fill")
                    .font(.caption)
                Text(restaurant.location)
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
        }
    }
}

/// Star rating badge.
struct RatingBadge: View {
    let rating: Double
    var font: Font = .caption

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(font)
                .foregroundStyle(.yellow)
            Text(String(format: "%.1f", rating))
                .font(font)
                .fontWeight(.semibold)
        }
    }
}

/// A single stat column used in the profile header (e.g. Followers, Following).
struct StatView: View {
    let count: Int
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.headline)
                .fontWeight(.semibold)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
