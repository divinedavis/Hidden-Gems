//
//  CreatePostView.swift
//  Hidden Gems
//
//  Created by Divine Davis on 3/16/26.
//

import SwiftUI
import PhotosUI
import Supabase
import MapKit

struct CreatePostView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(RecommendationsManager.self) private var recommendationsManager
    @Environment(AuthManager.self) private var authManager
    @State private var selectedRestaurant: Restaurant?
    @State private var caption = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var showingLocationPicker = false
    @State private var isPosting = false
    @State private var postErrorMessage: String?
    @State private var vibeTags: [String] = []
    @State private var tagInput = ""
    /// Category the poster wants this place tagged as. Prefills from
    /// the selected place's stored cuisine; if the user changes it
    /// before posting, the place row gets updated alongside the post
    /// so future posts about the same spot see the curated value.
    @State private var category: String = ""

    private let maxPhotos = 5
    private let maxCaptionLength = 124
    private let maxTags = 6
    private let categories = [
        "American", "New American", "Californian",
        "Italian", "Mexican", "Chinese", "Japanese",
        "Korean", "Thai", "Indian", "Vietnamese",
        "Mediterranean", "French", "Greek", "Spanish",
        "Middle Eastern", "Ethiopian", "Brazilian", "Peruvian",
        "Caribbean", "Soul Food", "Southern", "BBQ",
        "Seafood", "Steakhouse", "Pizza", "Burger",
        "Cocktail Bar", "Wine Bar", "Whiskey Bar", "Champagne Bar",
        "Beer Garden", "Sports Bar", "Dive Bar", "Tiki Bar",
        "Rooftop Bar", "Speakeasy", "Lounge",
        "Cafe", "Bakery", "Dessert",
        "Other"
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let postErrorMessage {
                        Text(postErrorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                    // Location Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Place")
                            .font(.headline)

                        Button {
                            showingLocationPicker = true
                        } label: {
                            HStack {
                                if let restaurant = selectedRestaurant {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(restaurant.name)
                                            .font(.subheadline)
                                            .foregroundStyle(.primary)
                                        Text(restaurant.location)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                } else {
                                    Text("Select a place")
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    // Category — appears as soon as a place is picked.
                    // Defaults to whatever Apple Maps tagged the place
                    // as; the user can correct it before posting.
                    if selectedRestaurant != nil {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Category")
                                .font(.headline)

                            Menu {
                                Picker("Category", selection: $category) {
                                    ForEach(categories, id: \.self) { c in
                                        Text(c).tag(c)
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(category.isEmpty ? "Select a category" : category)
                                        .foregroundStyle(category.isEmpty ? .secondary : .primary)
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }

                    // Photo Selection
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Photos")
                                .font(.headline)
                            
                            Spacer()
                            
                            Text("\(selectedImages.count)/\(maxPhotos)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                // Add photo button
                                PhotosPicker(selection: $selectedPhotos, maxSelectionCount: maxPhotos, matching: .images) {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.systemGray6))
                                        .frame(width: 100, height: 100)
                                        .overlay {
                                            VStack(spacing: 4) {
                                                Image(systemName: "plus")
                                                    .font(.title2)
                                                Text("Add")
                                                    .font(.caption)
                                            }
                                            .foregroundStyle(.secondary)
                                        }
                                }
                                .disabled(selectedImages.count >= maxPhotos)
                                .opacity(selectedImages.count >= maxPhotos ? 0.5 : 1.0)
                                
                                // Selected photos
                                ForEach(selectedImages.indices, id: \.self) { index in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: selectedImages[index])
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 100, height: 100)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                        
                                        // Remove button
                                        Button {
                                            selectedImages.remove(at: index)
                                            selectedPhotos.remove(at: index)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.title3)
                                                .foregroundStyle(.white)
                                                .background(Circle().fill(Color.black.opacity(0.6)))
                                        }
                                        .padding(4)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Caption
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Caption")
                                .font(.headline)

                            Spacer()

                            Text("\(caption.count)/\(maxCaptionLength)")
                                .font(.caption)
                                .foregroundStyle(caption.count > maxCaptionLength ? .red : .secondary)
                        }

                        TextEditor(text: $caption)
                            .frame(height: 120)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(caption.count > maxCaptionLength ? Color.red : Color.clear, lineWidth: 1)
                            )
                            .onChange(of: caption) { oldValue, newValue in
                                if newValue.count > maxCaptionLength {
                                    caption = String(newValue.prefix(maxCaptionLength))
                                }
                            }
                    }

                    // Vibes
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Vibes")
                                .font(.headline)
                            Spacer()
                            Text("\(vibeTags.count)/\(maxTags)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        VibeTagPicker(
                            tags: $vibeTags,
                            input: $tagInput,
                            maxTags: maxTags
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("New Recommendation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") { createPost() }
                        .disabled(!canPost || isPosting)
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingLocationPicker) {
                LocationPickerView(selectedRestaurant: $selectedRestaurant)
            }
            .onChange(of: selectedPhotos) { oldValue, newValue in
                Task {
                    await loadImages()
                }
            }
            .onChange(of: selectedRestaurant?.id) { _, _ in
                // When a new place is picked, prefill Category from
                // its stored cuisine. User can override before posting.
                if let r = selectedRestaurant, !r.cuisine.isEmpty {
                    category = r.cuisine
                }
            }
        }
    }
    
    private var canPost: Bool {
        selectedRestaurant != nil && !caption.isEmpty && caption.count <= maxCaptionLength
    }
    
    private func createPost() {
        guard let restaurant = selectedRestaurant else { return }
        isPosting = true
        postErrorMessage = nil
        Task {
            do {
                // Upload each picked photo to the media bucket before
                // inserting the post so the row references durable
                // public URLs, not in-memory UIImages.
                let ownerId = authManager.currentUser.id
                var uploadedURLs: [String] = []
                for image in selectedImages {
                    let url = try await MediaUploader.uploadJPEG(
                        image,
                        kind: .posts,
                        ownerId: ownerId
                    )
                    uploadedURLs.append(url)
                }

                // Persist the category override back to the place
                // row when the user picked something different from
                // what was stored, so future posts about the same
                // spot see the curated value.
                let trimmedCategory = category.trimmingCharacters(in: .whitespaces)
                let restaurantToUse: Restaurant
                if !trimmedCategory.isEmpty, trimmedCategory != restaurant.cuisine {
                    struct CuisineUpdate: Encodable { let cuisine: String }
                    try? await supabase
                        .from("restaurants")
                        .update(CuisineUpdate(cuisine: trimmedCategory))
                        .eq("id", value: restaurant.id.uuidString)
                        .execute()
                    var updated = Restaurant(
                        name: restaurant.name,
                        cuisine: trimmedCategory,
                        location: restaurant.location,
                        imageURL: restaurant.imageURL,
                        rating: restaurant.rating,
                        priceLevel: restaurant.priceLevel,
                        description: restaurant.description
                    )
                    updated.id = restaurant.id
                    updated.applePlaceID = restaurant.applePlaceID
                    updated.latitude = restaurant.latitude
                    updated.longitude = restaurant.longitude
                    restaurantToUse = updated
                } else {
                    restaurantToUse = restaurant
                }

                try await recommendationsManager.createPost(
                    restaurant: restaurantToUse,
                    note: caption,
                    user: authManager.currentUser,
                    vibeTags: vibeTags,
                    imageUrls: uploadedURLs
                )
                isPosting = false
                dismiss()
            } catch {
                isPosting = false
                postErrorMessage = "Could not post. \(error.localizedDescription)"
            }
        }
    }
    
    /// Rebuilds `selectedImages` from `selectedPhotos`. If a photo's
    /// transferable load fails we drop it from `selectedPhotos` too so
    /// the two arrays stay aligned — the remove-button uses the image
    /// index against `selectedPhotos`, so any drift would delete the
    /// wrong picker entry on the next tap.
    private func loadImages() async {
        var loaded: [UIImage] = []
        var kept: [PhotosPickerItem] = []
        for item in selectedPhotos {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                loaded.append(image)
                kept.append(item)
            }
        }
        selectedImages = loaded
        if kept.count != selectedPhotos.count {
            selectedPhotos = kept
        }
    }
}

struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthManager.self) private var authManager
    @Binding var selectedRestaurant: Restaurant?
    @State private var searchText = ""
    @State private var completer = ApplePlaceCompleter()
    @State private var resolving = false
    @State private var resolveError: String?
    @State private var recents: [Restaurant] = []

    var body: some View {
        NavigationStack {
            ZStack {
                List {
                    if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                        Section {
                            Text("Search Apple Maps for a restaurant, bar, café, or any place.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Section {
                            ForEach(completer.results, id: \.self) { result in
                                Button {
                                    Task { await selectAppleResult(result) }
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(result.title)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        if !result.subtitle.isEmpty {
                                            Text(result.subtitle)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        } header: {
                            Text("Suggestions from Apple Maps")
                        }
                    }

                    // The user's three most-recent places, shown when no
                    // search query is active. Lets repeat-posters skip the
                    // search step for spots they hit often.
                    if searchText.trimmingCharacters(in: .whitespaces).isEmpty,
                       !recents.isEmpty {
                        Section {
                            ForEach(recents) { r in
                                Button {
                                    selectedRestaurant = r
                                    dismiss()
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(r.name)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        if !r.location.isEmpty {
                                            Text(r.location)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        } header: {
                            Text("Recent")
                        }
                    }
                }

                if resolving {
                    Color.black.opacity(0.15).ignoresSafeArea()
                    ProgressView("Adding place…")
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .navigationTitle("Select a place")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search places")
            .onChange(of: searchText) { _, newValue in
                completer.update(query: newValue)
            }
            .alert("Couldn't add that place", isPresented: .constant(resolveError != nil)) {
                Button("OK") { resolveError = nil }
            } message: {
                Text(resolveError ?? "")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                await loadRecents()
            }
        }
    }

    /// Pulls the user's three most-recently-used restaurants from posts.
    /// Dedupes by restaurant id so revisited spots don't crowd the list.
    private func loadRecents() async {
        guard authManager.isSignedIn else { return }
        let uid = authManager.currentUser.id.uuidString
        struct PostRow: Decodable {
            let createdAt: Date
            let restaurant: RecentRestaurant?
            enum CodingKeys: String, CodingKey {
                case createdAt = "created_at"
                case restaurant = "restaurants"
            }
        }
        struct RecentRestaurant: Decodable {
            let id: UUID
            let name: String
            let cuisine: String?
            let location: String?
            let priceLevel: Int?
            let rating: Double?
            let imageUrl: String?
            let applePlaceId: String?
            let latitude: Double?
            let longitude: Double?
            enum CodingKeys: String, CodingKey {
                case id, name, cuisine, location, rating, latitude, longitude
                case priceLevel = "price_level"
                case imageUrl = "image_url"
                case applePlaceId = "apple_place_id"
            }
        }
        do {
            // Pull a small window of recent posts and dedupe by restaurant
            // client-side — PostgREST doesn't support DISTINCT ON.
            let rows: [PostRow] = try await supabase
                .from("posts")
                .select("created_at, restaurants(id, name, cuisine, location, rating, price_level, image_url, apple_place_id, latitude, longitude)")
                .eq("user_id", value: uid)
                .order("created_at", ascending: false)
                .limit(30)
                .execute()
                .value
            var seen: Set<UUID> = []
            var collected: [Restaurant] = []
            for row in rows {
                guard let r = row.restaurant, !seen.contains(r.id) else { continue }
                seen.insert(r.id)
                var restaurant = Restaurant(
                    name: r.name,
                    cuisine: r.cuisine ?? "",
                    location: r.location ?? "",
                    imageURL: r.imageUrl ?? "",
                    rating: r.rating ?? 0,
                    priceLevel: r.priceLevel ?? 0,
                    description: "",
                    applePlaceID: r.applePlaceId ?? "",
                    latitude: r.latitude ?? 0,
                    longitude: r.longitude ?? 0
                )
                restaurant.id = r.id
                collected.append(restaurant)
                if collected.count == 3 { break }
            }
            recents = collected
        } catch {
            debugLog("Recent places fetch error", error)
        }
    }

    /// Resolves an MKLocalSearchCompletion to a full POI, upserts a
    /// restaurants row keyed on its Apple identifier, and hands the
    /// resulting Restaurant back to the parent.
    private func selectAppleResult(_ completion: MKLocalSearchCompletion) async {
        resolving = true
        defer { resolving = false }
        do {
            let request = MKLocalSearch.Request(completion: completion)
            let response = try await MKLocalSearch(request: request).start()
            guard let item = response.mapItems.first else {
                resolveError = "Apple Maps couldn't resolve that place. Try another."
                return
            }
            let restaurant = try await upsertApplePlace(item)
            selectedRestaurant = restaurant
            dismiss()
        } catch {
            resolveError = error.localizedDescription
        }
    }

    /// Upserts a `restaurants` row from an Apple `MKMapItem` keyed on
    /// the Apple place identifier. Returns the resulting Restaurant
    /// (with the server-assigned UUID).
    private func upsertApplePlace(_ item: MKMapItem) async throws -> Restaurant {
        let placemark = item.placemark
        let lat = placemark.coordinate.latitude
        let lon = placemark.coordinate.longitude

        // Synthesize a stable id for places that don't expose a
        // first-party Apple identifier — round coordinates so the
        // same place searched again hashes the same way.
        let appleID: String
        if let id = item.identifier?.rawValue, !id.isEmpty {
            appleID = id
        } else {
            let n = item.name ?? "place"
            appleID = "syn:\(n.lowercased()):\(String(format: "%.4f,%.4f", lat, lon))"
        }

        let category = appCategory(for: item)
        let name = item.name ?? "Unnamed place"
        let location = formattedAddress(placemark)

        struct UpsertRow: Encodable {
            let apple_place_id: String
            let name: String
            let cuisine: String
            let location: String
            let latitude: Double
            let longitude: Double
        }
        struct ReturnedRow: Decodable {
            let id: UUID
            let name: String
            let cuisine: String?
            let location: String?
            let priceLevel: Int?
            let rating: Double?
            let imageUrl: String?
            let applePlaceId: String?
            let latitude: Double?
            let longitude: Double?
            enum CodingKeys: String, CodingKey {
                case id, name, cuisine, location, rating, latitude, longitude
                case priceLevel = "price_level"
                case imageUrl = "image_url"
                case applePlaceId = "apple_place_id"
            }
        }

        let rows: [ReturnedRow] = try await supabase
            .from("restaurants")
            .upsert(
                UpsertRow(
                    apple_place_id: appleID,
                    name: name,
                    cuisine: category,
                    location: location,
                    latitude: lat,
                    longitude: lon
                ),
                onConflict: "apple_place_id",
                ignoreDuplicates: false
            )
            .select("id, name, cuisine, location, rating, price_level, image_url, apple_place_id, latitude, longitude")
            .execute()
            .value

        guard let row = rows.first else {
            throw NSError(domain: "ApplePlaceUpsert", code: -1)
        }
        var r = Restaurant(
            name: row.name,
            cuisine: row.cuisine ?? "",
            location: row.location ?? "",
            imageURL: row.imageUrl ?? "",
            rating: row.rating ?? 0,
            priceLevel: row.priceLevel ?? 0,
            description: ""
        )
        r.id = row.id
        r.applePlaceID = row.applePlaceId ?? appleID
        r.latitude = row.latitude ?? lat
        r.longitude = row.longitude ?? lon
        return r
    }

    private func formattedAddress(_ p: MKPlacemark) -> String {
        var bits: [String] = []
        if let s = p.thoroughfare {
            if let n = p.subThoroughfare { bits.append("\(n) \(s)") } else { bits.append(s) }
        }
        let cityState = [p.locality, p.administrativeArea].compactMap { $0 }.joined(separator: ", ")
        if !cityState.isEmpty { bits.append(cityState) }
        return bits.joined(separator: ", ")
    }

    /// Maps Apple's `MKPointOfInterestCategory` onto our category set
    /// so newly-added places line up with the existing seeded data.
    private func appCategory(for item: MKMapItem) -> String {
        switch item.pointOfInterestCategory {
        case .cafe: return "Cafe"
        case .bakery: return "Bakery"
        case .brewery: return "Beer Garden"
        case .winery: return "Wine Bar"
        case .nightlife: return "Cocktail Bar"
        default: return "American"
        }
    }

}

// MARK: - Apple Place Completer

/// Drives the Place picker's autocomplete via `MKLocalSearchCompleter`,
/// scoped to points of interest (vs. addresses). Updates `results` as
/// the user types and SwiftUI observes via @Observable.
@Observable
class ApplePlaceCompleter: NSObject, MKLocalSearchCompleterDelegate {
    var results: [MKLocalSearchCompletion] = []
    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .pointOfInterest
    }

    func update(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if trimmed.count >= 2 {
            completer.queryFragment = trimmed
        } else {
            results = []
        }
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = Array(completer.results.prefix(20))
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        results = []
    }
}


#Preview {
    CreatePostView()
        .environment(AuthManager())
        .environment(RecommendationsManager())
}
