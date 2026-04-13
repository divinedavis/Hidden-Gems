//
//  CreatePostView.swift
//  Hidden Gems
//
//  Created by Divine Davis on 3/16/26.
//

import SwiftUI
import PhotosUI
import Supabase

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
    
    private let maxPhotos = 5
    private let maxCaptionLength = 124
    
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
                        Text("Restaurant")
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
                                    Text("Select a restaurant")
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
                try await recommendationsManager.createPost(
                    restaurant: restaurant,
                    note: caption,
                    user: authManager.currentUser
                )
                isPosting = false
                dismiss()
            } catch {
                isPosting = false
                postErrorMessage = "Could not post. \(error.localizedDescription)"
            }
        }
    }
    
    private func loadImages() async {
        selectedImages.removeAll()
        
        for item in selectedPhotos {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                selectedImages.append(image)
            }
        }
    }
}

struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedRestaurant: Restaurant?
    @State private var searchText = ""
    @State private var restaurants: [Restaurant] = []
    @State private var isLoading = true

    private var filteredRestaurants: [Restaurant] {
        if searchText.isEmpty { return restaurants }
        return restaurants.filter { restaurant in
            restaurant.name.localizedCaseInsensitiveContains(searchText) ||
            restaurant.location.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading restaurants…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filteredRestaurants) { restaurant in
                        Button {
                            selectedRestaurant = restaurant
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(restaurant.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(restaurant.location)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if selectedRestaurant?.id == restaurant.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Restaurant")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search restaurants")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task { await loadRestaurants() }
        }
    }

    private func loadRestaurants() async {
        struct RestaurantRow: Decodable {
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
            let rows: [RestaurantRow] = try await supabase
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
            print("Restaurants fetch error: \(error)")
        }
        isLoading = false
    }
}

#Preview {
    CreatePostView()
        .environment(AuthManager())
        .environment(RecommendationsManager())
}
