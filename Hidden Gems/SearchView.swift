//
//  SearchView.swift
//  Hidden Gems
//
//  Created by Divine Davis on 3/16/26.
//

import SwiftUI

struct SearchView: View {
    @State private var searchText = ""
    @State private var restaurants = Restaurant.samples
    
    var filteredRestaurants: [Restaurant] {
        if searchText.isEmpty {
            return restaurants
        }
        return restaurants.filter { restaurant in
            restaurant.name.localizedCaseInsensitiveContains(searchText) ||
            restaurant.cuisine.localizedCaseInsensitiveContains(searchText) ||
            restaurant.location.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filteredRestaurants) { restaurant in
                        RestaurantRow(restaurant: restaurant)
                    }
                }
                .padding()
            }
            .navigationTitle("Search")
            .searchable(text: $searchText, prompt: "Search restaurants, cuisine, or location")
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
                
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                    Text(String(format: "%.1f", restaurant.rating))
                        .font(.caption)
                        .fontWeight(.semibold)
                }
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
