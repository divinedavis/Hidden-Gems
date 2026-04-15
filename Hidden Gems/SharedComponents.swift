//
//  SharedComponents.swift
//  Hidden Gems
//
//  Created by Divine Davis on 3/16/26.
//

import SwiftUI

/// Writes to the Xcode console in Debug builds only. Release builds
/// compile this to a no-op so error details — which can contain
/// request URLs, user ids, and other metadata — never leak into device
/// crash logs or iOS's unified logging where a sufficiently motivated
/// attacker could read them.
func debugLog(_ label: String, _ value: Any? = nil) {
    #if DEBUG
    if let value {
        print("[HiddenGems] \(label): \(value)")
    } else {
        print("[HiddenGems] \(label)")
    }
    #endif
}

/// Returns a URL only if the string parses and uses the https scheme.
/// Used to guard AsyncImage against missing, malformed, or non-https URLs
/// (which could be used for SSRF if we ever proxied images server-side).
func safeImageURL(from string: String) -> URL? {
    guard !string.isEmpty,
          let url = URL(string: string),
          url.scheme?.lowercased() == "https" else { return nil }
    return url
}

/// AsyncImage that validates the URL is https, fills its container with
/// `scaledToFill` + hard clipping (so it can never push its parent wider),
/// shows a ProgressView while loading, and falls through to a photo
/// placeholder on failure or when the URL is missing/unsafe.
///
/// Callers must give this view an explicit frame (e.g. `.frame(height:)`
/// plus `.frame(maxWidth: .infinity)` or a fixed square). The GeometryReader
/// inside guarantees the image will clip to those bounds no matter how
/// large the underlying photo is.
struct SafeAsyncImage: View {
    let urlString: String

    var body: some View {
        GeometryReader { geo in
            Group {
                if let url = safeImageURL(from: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: geo.size.width, height: geo.size.height)
                                .clipped()
                        case .failure:
                            placeholder
                                .frame(width: geo.size.width, height: geo.size.height)
                        case .empty:
                            ProgressView()
                                .frame(width: geo.size.width, height: geo.size.height)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    placeholder
                        .frame(width: geo.size.width, height: geo.size.height)
                }
            }
        }
    }

    private var placeholder: some View {
        ZStack {
            Color.gray.opacity(0.15)
            Image(systemName: "photo")
                .font(.largeTitle)
                .foregroundStyle(.gray)
        }
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
