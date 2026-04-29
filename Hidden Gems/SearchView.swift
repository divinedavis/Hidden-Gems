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
    @State private var selectedVibe: String?
    @State private var followsFeed: [Restaurant] = []
    @Environment(SavedRestaurantsManager.self) private var savedManager
    @Environment(LikesManager.self) private var likesManager
    @Environment(FollowManager.self) private var followManager
    @Environment(AuthManager.self) private var authManager

    /// True when the user is actively narrowing — flips the layout
    /// from the curated carousel home to the flat filtered list.
    private var isFiltering: Bool {
        !searchText.isEmpty || selectedVibe != nil
    }

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

                ScrollView {
                    if !hasLoadedOnce {
                        ProgressView("Loading restaurants…")
                            .padding(.top, 80)
                            .frame(maxWidth: .infinity)
                    } else if isFiltering {
                        filteredList
                    } else {
                        carouselHome
                    }
                }
                .refreshable { await loadAll() }
            }
            .navigationTitle("Search")
            .searchable(text: $searchText, prompt: "Search restaurants, cuisine, or location")
            .task(id: "search-load") {
                guard !hasLoadedOnce else { return }
                await loadAll()
            }
        }
    }

    /// Flat filtered list, used when the user is searching or has
    /// tapped a vibe chip. Same shape as before so a known-good search
    /// flow doesn't regress while we add the curated home above it.
    @ViewBuilder
    private var filteredList: some View {
        if filteredRestaurants.isEmpty {
            ContentUnavailableView(
                "No matches",
                systemImage: "magnifyingglass",
                description: Text(selectedVibe == nil
                    ? "Try a different search."
                    : "No spots tagged with this vibe yet. Be the first to recommend one!")
            )
            .padding(.top, 60)
        } else {
            LazyVStack(spacing: 12) {
                ForEach(filteredRestaurants) { item in
                    RestaurantRow(restaurant: item.restaurant)
                }
            }
            .padding()
        }
    }

    /// Airbnb-style stack of horizontal carousels: one for posts from
    /// people you follow, then one per curated vibe. Sections with no
    /// data hide themselves so the home doesn't render empty rails.
    @ViewBuilder
    private var carouselHome: some View {
        LazyVStack(alignment: .leading, spacing: 24) {
            if !followsFeed.isEmpty {
                CarouselSection(
                    title: "From people you follow",
                    restaurants: followsFeed
                )
            }
            ForEach(Vibe.curated, id: \.self) { vibe in
                let key = Vibe.normalize(vibe)
                let matches = restaurants
                    .filter { $0.vibeTags.contains(key) }
                    .prefix(12)
                    .map(\.restaurant)
                if !matches.isEmpty {
                    CarouselSection(title: vibe, restaurants: Array(matches))
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func loadAll() async {
        async let r: Void = loadRestaurants()
        async let f: Void = loadFollowsFeed()
        _ = await (r, f)
        hasLoadedOnce = true
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
    }

    /// Pulls the most recent posts from people the session user
    /// follows and dedupes to a list of restaurants. Skips when the
    /// user follows nobody so we don't render an empty rail.
    private func loadFollowsFeed() async {
        let following = Array(followManager.followedUsers).map(\.uuidString)
        guard !following.isEmpty else {
            followsFeed = []
            return
        }
        do {
            let posts: [SupabaseFeedPost] = try await supabase
                .from("feed")
                .select()
                .in("user_id", values: following)
                .order("created_at", ascending: false)
                .limit(40)
                .execute()
                .value
            var seen = Set<UUID>()
            var picked: [Restaurant] = []
            for post in posts {
                guard !seen.contains(post.restaurantId) else { continue }
                seen.insert(post.restaurantId)
                let rec = post.toRecommendation()
                picked.append(rec.restaurant)
                if picked.count >= 12 { break }
            }
            followsFeed = picked
        } catch {
            debugLog("SearchView follows feed fetch error", error)
        }
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

/// One titled rail of horizontally-scrolling restaurant cards.
struct CarouselSection: View {
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
                        RestaurantCard(restaurant: restaurant)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

/// Square-image card used inside `CarouselSection`. Sized so two
/// cards fit comfortably across an iPhone width with a peek of the
/// next one — the visual cue that the rail scrolls.
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
