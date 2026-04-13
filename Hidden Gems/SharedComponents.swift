//
//  SharedComponents.swift
//  Hidden Gems
//
//  Created by Divine Davis on 3/16/26.
//

import SwiftUI

/// Returns a URL only if the string parses and uses the https scheme.
/// Used to guard AsyncImage against missing, malformed, or non-https URLs
/// (which could be used for SSRF if we ever proxied images server-side).
func safeImageURL(from string: String) -> URL? {
    guard !string.isEmpty,
          let url = URL(string: string),
          url.scheme?.lowercased() == "https" else { return nil }
    return url
}

/// AsyncImage that validates the URL is https, shows a ProgressView while
/// loading, and falls through to a photo placeholder on failure or when
/// the URL is missing/unsafe.
struct SafeAsyncImage: View {
    let urlString: String

    var body: some View {
        Group {
            if let url = safeImageURL(from: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        placeholder
                    case .empty:
                        ProgressView()
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                placeholder
            }
        }
    }

    private var placeholder: some View {
        Image(systemName: "photo")
            .font(.largeTitle)
            .foregroundStyle(.gray)
    }
}

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
