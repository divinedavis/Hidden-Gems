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
    @State private var isLoading = true
    @State private var selectedVibe: String?
    @Environment(SavedRestaurantsManager.self) private var savedManager
    @Environment(LikesManager.self) private var likesManager

    var filteredRestaurants: [RestaurantWithVibes] {
        var items = restaurants
        if let selectedVibe {
            items = items.filter { $0.vibeTags.contains(selectedVibe) }
        }
        if !searchText.isEmpty {
            items = items.filter { item in
                item.restaurant.name.localizedCaseInsensitiveContains(searchText) ||
                item.restaurant.cuisine.localizedCaseInsensitiveContains(searchText) ||
                item.restaurant.location.localizedCaseInsensitiveContains(searchText)
            }
        }
        return items
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VibeFilterRow(selected: $selectedVibe)
                    .padding(.vertical, 8)

                Group {
                    if isLoading && restaurants.isEmpty {
                        ProgressView("Loading restaurants…")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if filteredRestaurants.isEmpty {
                        ContentUnavailableView(
                            "No matches",
                            systemImage: "magnifyingglass",
                            description: Text(selectedVibe == nil
                                ? "Try a different search."
                                : "No spots tagged with this vibe yet. Be the first to recommend one!")
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredRestaurants) { item in
                                    RestaurantRow(restaurant: item.restaurant)
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Search")
            .searchable(text: $searchText, prompt: "Search restaurants, cuisine, or location")
            .task { await loadRestaurants() }
            .refreshable { await loadRestaurants() }
        }
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
        isLoading = false
    }
}

struct RestaurantWithVibes: Identifiable {
    let restaurant: Restaurant
    let vibeTags: [String]
    var id: UUID { restaurant.id }
}

/// Horizontal chip row for the curated vibes. Tapping a chip toggles
/// it as the active filter; the "All" chip clears the filter.
struct VibeFilterRow: View {
    @Binding var selected: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                VibeChip(label: "All", selected: selected == nil)
                    .onTapGesture { selected = nil }

                ForEach(Vibe.curated, id: \.self) { vibe in
                    let key = Vibe.normalize(vibe)
                    VibeChip(label: vibe, selected: selected == key)
                        .onTapGesture {
                            selected = (selected == key) ? nil : key
                        }
                }
            }
            .padding(.horizontal)
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

                RestaurantMetaInfo(restaurant: restaurant)

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
