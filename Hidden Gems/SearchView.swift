//
//  SearchView.swift
//  Hidden Gems
//
//  Created by Divine Davis on 3/16/26.
//

import SwiftUI
import Supabase

struct SearchView: View {
    @State private var searchText = ""
    @State private var restaurants: [RestaurantWithVibes] = []
    @State private var hasLoadedOnce = false
    @Environment(SavedRestaurantsManager.self) private var savedManager
    @Environment(LikesManager.self) private var likesManager

    private var isSearching: Bool { !searchText.isEmpty }

    var filteredRestaurants: [Restaurant] {
        guard isSearching else { return [] }
        return restaurants
            .map(\.restaurant)
            .filter { r in
                r.name.localizedCaseInsensitiveContains(searchText) ||
                r.cuisine.localizedCaseInsensitiveContains(searchText) ||
                r.location.localizedCaseInsensitiveContains(searchText)
            }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if !hasLoadedOnce {
                    ProgressView("Loading restaurants…")
                        .padding(.top, 80)
                        .frame(maxWidth: .infinity)
                } else if isSearching {
                    searchResults
                } else {
                    vibeCarousels
                }
            }
            .refreshable { await loadRestaurants() }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search places")
            .task(id: "search-load") {
                guard !hasLoadedOnce else { return }
                await loadRestaurants()
            }
        }
    }

    @ViewBuilder
    private var searchResults: some View {
        if filteredRestaurants.isEmpty {
            ContentUnavailableView(
                "No matches",
                systemImage: "magnifyingglass",
                description: Text("Try a different search.")
            )
            .padding(.top, 60)
        } else {
            LazyVStack(spacing: 12) {
                ForEach(filteredRestaurants) { restaurant in
                    NavigationLink {
                        RestaurantDetailView(restaurant: restaurant)
                    } label: {
                        RestaurantRow(restaurant: restaurant)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }

    /// Stack of horizontal rails, one per curated vibe. Rails with no
    /// matching restaurants hide themselves so the home doesn't render
    /// empty rows for vibes that haven't picked up posts yet.
    @ViewBuilder
    private var vibeCarousels: some View {
        LazyVStack(alignment: .leading, spacing: 24) {
            ForEach(Vibe.curated, id: \.self) { vibe in
                let key = Vibe.normalize(vibe)
                let matches = restaurants
                    .filter { $0.vibeTags.contains(key) }
                    .prefix(12)
                    .map(\.restaurant)
                if !matches.isEmpty {
                    VibeCarousel(title: vibe, restaurants: Array(matches))
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func loadRestaurants() async {
        struct FetchedRestaurant: Decodable {
            let id: UUID
            let name: String
            let cuisine: String?
            let location: String?
            let rating: Double?
            let priceLevel: Int?
            let imageUrl: String?
            let description: String?
            let vibeTags: [String]?
            enum CodingKeys: String, CodingKey {
                case id, name, cuisine, location, rating, description
                case priceLevel = "price_level"
                case imageUrl = "image_url"
                case vibeTags = "vibe_tags"
            }
        }
        do {
            let rows: [FetchedRestaurant] = try await supabase
                .from("restaurants_with_vibes")
                .select("id, name, cuisine, location, rating, price_level, image_url, description, vibe_tags")
                .order("name")
                .execute()
                .value
            restaurants = rows.map { row in
                var r = Restaurant(
                    name: row.name,
                    cuisine: row.cuisine ?? "",
                    location: row.location ?? "",
                    imageURL: row.imageUrl ?? "",
                    rating: row.rating ?? 0,
                    priceLevel: row.priceLevel ?? 1,
                    description: row.description ?? ""
                )
                r.id = row.id
                return RestaurantWithVibes(restaurant: r, vibeTags: row.vibeTags ?? [])
            }
        } catch {
            debugLog("SearchView restaurants fetch error", error)
        }
        hasLoadedOnce = true
    }
}

struct RestaurantWithVibes: Identifiable {
    let restaurant: Restaurant
    let vibeTags: [String]
    var id: UUID { restaurant.id }
}

/// One titled rail of horizontally-scrolling restaurant cards.
struct VibeCarousel: View {
    let title: String
    let restaurants: [Restaurant]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(restaurants) { restaurant in
                        NavigationLink {
                            RestaurantDetailView(restaurant: restaurant)
                        } label: {
                            RestaurantCard(restaurant: restaurant)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

/// Square-image card sized so two cards fit across an iPhone width
/// with a peek of the next — the visual cue that the rail scrolls.
struct RestaurantCard: View {
    let restaurant: Restaurant

    private let cardWidth: CGFloat = 180

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let url = URL(string: restaurant.imageURL), !restaurant.imageURL.isEmpty {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            default:
                                placeholder
                            }
                        }
                    } else {
                        placeholder
                    }
                }
                .frame(width: cardWidth, height: cardWidth)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                if restaurant.rating > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                        Text(String(format: "%.1f", restaurant.rating))
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(8)
                }
            }

            Text(restaurant.name)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text(metaLine)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: cardWidth, alignment: .leading)
    }

    private var metaLine: String {
        var parts: [String] = []
        if !restaurant.cuisine.isEmpty { parts.append(restaurant.cuisine) }
        if restaurant.priceLevel > 0 {
            parts.append(String(repeating: "$", count: restaurant.priceLevel))
        }
        if !restaurant.location.isEmpty { parts.append(restaurant.location) }
        return parts.joined(separator: " · ")
    }

    private var placeholder: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .overlay {
                Image(systemName: "photo")
                    .foregroundStyle(.gray)
            }
    }
}

struct RestaurantRow: View {
    let restaurant: Restaurant

    var body: some View {
        HStack(spacing: 12) {
            // Restaurant image
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 80, height: 80)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundStyle(.gray)
                }

            // Restaurant info
            VStack(alignment: .leading, spacing: 4) {
                Text(restaurant.name)
                    .font(.headline)

                RestaurantMetaInfo(restaurant: restaurant, locationIsTappable: false)

                RatingBadge(rating: restaurant.rating)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

#Preview {
    SearchView()
}
