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
    @State private var restaurants: [Restaurant] = []
    @State private var hasLoadedOnce = false
    @Environment(SavedRestaurantsManager.self) private var savedManager
    @Environment(LikesManager.self) private var likesManager

    var filteredRestaurants: [Restaurant] {
        guard !searchText.isEmpty else { return restaurants }
        return restaurants.filter { r in
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
                } else if filteredRestaurants.isEmpty {
                    ContentUnavailableView(
                        "No matches",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different search.")
                    )
                    .padding(.top, 60)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredRestaurants) { restaurant in
                            RestaurantRow(restaurant: restaurant)
                        }
                    }
                    .padding()
                }
            }
            .refreshable { await loadRestaurants() }
            .navigationTitle("Search")
            .searchable(text: $searchText, prompt: "Search places")
            .task(id: "search-load") {
                guard !hasLoadedOnce else { return }
                await loadRestaurants()
            }
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
            enum CodingKeys: String, CodingKey {
                case id, name, cuisine, location, rating, description
                case priceLevel = "price_level"
                case imageUrl = "image_url"
            }
        }
        do {
            let rows: [FetchedRestaurant] = try await supabase
                .from("restaurants")
                .select("id, name, cuisine, location, rating, price_level, image_url, description")
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
                return r
            }
        } catch {
            debugLog("SearchView restaurants fetch error", error)
        }
        hasLoadedOnce = true
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
