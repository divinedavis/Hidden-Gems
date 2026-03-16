//
//  CreatePostView.swift
//  Hidden Gems
//
//  Created by Divine Davis on 3/16/26.
//

import SwiftUI
import PhotosUI

struct CreatePostView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRestaurant: Restaurant?
    @State private var caption = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var showingLocationPicker = false
    
    private let maxPhotos = 5
    private let maxCaptionLength = 124
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
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
                    Button("Post") {
                        createPost()
                    }
                    .disabled(!canPost)
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
        // TODO: Implement post creation
        // For now, just dismiss
        dismiss()
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
    
    private var filteredRestaurants: [Restaurant] {
        if searchText.isEmpty {
            return Restaurant.samples
        }
        return Restaurant.samples.filter { restaurant in
            restaurant.name.localizedCaseInsensitiveContains(searchText) ||
            restaurant.location.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
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
            .navigationTitle("Select Restaurant")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search restaurants")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    CreatePostView()
}
