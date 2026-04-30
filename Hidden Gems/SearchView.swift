//
//  SearchView.swift
//  Hidden Gems
//
//  Created by Divine Davis on 3/16/26.
//

import SwiftUI
import Supabase
import CoreLocation

struct SearchView: View {
    @State private var searchText = ""
    @State private var restaurants: [RestaurantWithVibes] = []
    @State private var hasLoadedOnce = false
    @State private var radiusMiles: Double? = nil
    @State private var minTier: RecommenderTier? = nil
    /// Restaurant ids posted by at least one user at or above
    /// `minTier`. Populated by `loadTopRecommendedIds` whenever the
    /// tier changes; nil means "haven't fetched yet" (distinct from
    /// "fetched, came back empty").
    @State private var topRestaurantIds: Set<UUID>? = nil
    @Environment(SavedRestaurantsManager.self) private var savedManager
    @Environment(LikesManager.self) private var likesManager
    @Environment(LocationManager.self) private var locationManager

    private var isSearching: Bool { !searchText.isEmpty }
    private var isRadiusFiltered: Bool { radiusMiles != nil }
    private var isTierFiltered: Bool { minTier != nil }
    private var isAnyFilterActive: Bool {
        isSearching || isRadiusFiltered || isTierFiltered
    }

    /// Returns nil for restaurants without coords or when no user
    /// location is known yet — those are excluded from radius results
    /// so we don't surface places we can't measure distance to.
    private func distanceMiles(to r: Restaurant) -> Double? {
        guard let userLoc = locationManager.userLocation else { return nil }
        guard r.latitude != 0 || r.longitude != 0 else { return nil }
        let placeLoc = CLLocation(latitude: r.latitude, longitude: r.longitude)
        return userLoc.distance(from: placeLoc) / 1609.344
    }

    var filteredRestaurants: [Restaurant] {
        let base: [Restaurant]
        if isSearching {
            base = restaurants.map(\.restaurant).filter { r in
                r.name.localizedCaseInsensitiveContains(searchText) ||
                r.cuisine.localizedCaseInsensitiveContains(searchText) ||
                r.location.localizedCaseInsensitiveContains(searchText)
            }
        } else if isRadiusFiltered || isTierFiltered {
            base = restaurants.map(\.restaurant)
        } else {
            return []
        }

        let tierFiltered: [Restaurant]
        if isTierFiltered {
            // While the top-recommenders query is in flight (ids == nil)
            // show nothing — better than briefly flashing all results.
            guard let ids = topRestaurantIds else { return [] }
            tierFiltered = base.filter { ids.contains($0.id) }
        } else {
            tierFiltered = base
        }

        guard let radius = radiusMiles else { return tierFiltered }
        return tierFiltered
            .compactMap { r -> (Restaurant, Double)? in
                guard let d = distanceMiles(to: r), d <= radius else { return nil }
                return (r, d)
            }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if !hasLoadedOnce {
                    ProgressView("Loading restaurants…")
                        .padding(.top, 80)
                        .frame(maxWidth: .infinity)
                } else if isAnyFilterActive {
                    searchResults
                } else {
                    vibeCarousels
                }
            }
            .refreshable { await loadRestaurants() }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search places")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 4) {
                        tierMenu
                        radiusMenu
                    }
                }
            }
            .task(id: "search-load") {
                guard !hasLoadedOnce else { return }
                await loadRestaurants()
            }
            .task(id: minTier) {
                await loadTopRecommendedIds()
            }
        }
    }

    private var radiusMenu: some View {
        Menu {
            Button {
                radiusMiles = nil
            } label: {
                Label("Any distance", systemImage: radiusMiles == nil ? "checkmark" : "")
            }
            ForEach([1.0, 2.0, 5.0, 10.0], id: \.self) { miles in
                Button {
                    selectRadius(miles)
                } label: {
                    let isCurrent = radiusMiles == miles
                    Label("Within \(Int(miles)) mi", systemImage: isCurrent ? "checkmark" : "")
                }
            }
        } label: {
            Image(systemName: isRadiusFiltered ? "location.fill" : "location")
        }
    }

    private func selectRadius(_ miles: Double) {
        radiusMiles = miles
        // Nudge CoreLocation in case the app launched before the user
        // granted permission (e.g. they tapped "Don't Allow" first run
        // but now want near-me search).
        if locationManager.authorizationStatus == .notDetermined ||
           locationManager.authorizationStatus == .denied {
            locationManager.requestPermission()
        }
    }

    private var tierMenu: some View {
        Menu {
            Button {
                minTier = nil
            } label: {
                Label("Anyone", systemImage: minTier == nil ? "checkmark" : "")
            }
            ForEach(RecommenderTier.allCases) { tier in
                Button {
                    minTier = tier
                } label: {
                    let isCurrent = minTier == tier
                    Label("\(tier.label) (\(tier.rawValue)+ recs)",
                          systemImage: isCurrent ? "checkmark" : tier.systemImage)
                }
            }
        } label: {
            Image(systemName: isTierFiltered ? "rosette" : "person.crop.circle.badge.checkmark")
                .foregroundStyle(isTierFiltered ? (minTier?.tint ?? .accentColor) : .primary)
        }
    }

    /// Pulls the set of restaurant ids posted by at least one user
    /// whose `recommendation_count >= minTier.rawValue`. Cached as a
    /// Set so `filteredRestaurants` can intersect in O(n) on every
    /// keystroke without re-hitting the network.
    private func loadTopRecommendedIds() async {
        guard let tier = minTier else {
            topRestaurantIds = nil
            return
        }
        topRestaurantIds = nil // signal "loading" to filteredRestaurants
        struct Row: Decodable {
            let restaurantId: UUID
            enum CodingKeys: String, CodingKey {
                case restaurantId = "restaurant_id"
            }
        }
        do {
            let rows: [Row] = try await supabase
                .from("top_recommended_restaurants")
                .select("restaurant_id")
                .gte("max_poster_count", value: tier.rawValue)
                .execute()
                .value
            // Only commit if the user hasn't switched tiers mid-flight.
            guard minTier == tier else { return }
            topRestaurantIds = Set(rows.map(\.restaurantId))
        } catch {
            debugLog("top_recommended_restaurants fetch error", error)
            // On error (e.g. view doesn't exist yet because migration
            // 011 hasn't been applied) treat the filter as a no-op
            // rather than wedging the search list.
            if minTier == tier {
                topRestaurantIds = Set(restaurants.map { $0.restaurant.id })
            }
        }
    }

    @ViewBuilder
    private var searchResults: some View {
        if filteredRestaurants.isEmpty {
            emptyResultsView
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

    @ViewBuilder
    private var emptyResultsView: some View {
        if isTierFiltered, topRestaurantIds == nil {
            ContentUnavailableView(
                "Loading top spots…",
                systemImage: "rosette",
                description: Text("Pulling places from your top recommenders.")
            )
            .padding(.top, 60)
        } else if isRadiusFiltered, locationManager.userLocation == nil {
            switch locationManager.authorizationStatus {
            case .denied, .restricted:
                ContentUnavailableView(
                    "Location access off",
                    systemImage: "location.slash",
                    description: Text("Enable location in Settings to search nearby.")
                )
                .padding(.top, 60)
            default:
                ContentUnavailableView(
                    "Finding your location…",
                    systemImage: "location.circle",
                    description: Text("This only takes a moment.")
                )
                .padding(.top, 60)
            }
        } else if isTierFiltered, let tier = minTier, !isSearching, !isRadiusFiltered {
            ContentUnavailableView(
                "No \(tier.label) spots yet",
                systemImage: tier.systemImage,
                description: Text("Try a lower tier or check back as more posts roll in.")
            )
            .padding(.top, 60)
        } else if isRadiusFiltered, !isSearching {
            ContentUnavailableView(
                "Nothing within \(Int(radiusMiles ?? 0)) mi",
                systemImage: "mappin.slash",
                description: Text("Try a wider radius.")
            )
            .padding(.top, 60)
        } else {
            ContentUnavailableView(
                "No matches",
                systemImage: "magnifyingglass",
                description: Text("Try a different search.")
            )
            .padding(.top, 60)
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
