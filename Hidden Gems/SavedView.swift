//
//  SavedView.swift
//  Hidden Gems
//
//  Created by Divine Davis on 3/16/26.
//

import SwiftUI

struct SavedView: View {
    @State private var savedRestaurants = Restaurant.samples
    
    var body: some View {
        NavigationStack {
            if savedRestaurants.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "bookmark")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                    
                    Text("No Saved Places")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Bookmark restaurants to save them here")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(savedRestaurants) { restaurant in
                            SavedRestaurantCard(restaurant: restaurant)
                        }
                    }
                    .padding()
                }
            }
            
            navigationTitle("Saved")
        }
    }
}

struct SavedRestaurantCard: View {
    let restaurant: Restaurant
    @State private var isSaved = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Restaurant image
            RoundedRectangle(cornerRadius: 0)
                .fill(Color.gray.opacity(0.2))
                .aspectRatio(16/9, contentMode: .fit)
                .overlay {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.gray)
                }
            
            // Restaurant info
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(restaurant.name)
                            .font(.title3)
                            .fontWeight(.bold)
                        
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
                    
                    Spacer()
                    
                    Button {
                        isSaved.toggle()
                    } label: {
                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            .font(.title3)
                            .foregroundStyle(.primary)
                    }
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                    Text(String(format: "%.1f", restaurant.rating))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .padding(.top, 4)
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}

#Preview {
    SavedView()
}
