//
//  SavedView.swift
//  Hidden Gems
//
//  Created by Divine Davis on 3/16/26.
//

import SwiftUI

struct SavedView: View {
    @Environment(SavedRestaurantsManager.self) private var savedManager
    @Environment(LikesManager.self) private var likesManager
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        NavigationStack {
            Group {
                if savedManager.savedRestaurants.isEmpty {
                    ScrollView {
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
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                        .padding()
                    }
                    .refreshable { await reload() }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(savedManager.savedRestaurants) { restaurant in
                                SavedRestaurantCard(restaurant: restaurant)
                            }
                        }
                        .padding()
                    }
                    .refreshable { await reload() }
                }
            }
            .navigationTitle("Saved")
            .task(id: authManager.currentUser.id) {
                await reload()
            }
        }
    }

    private func reload() async {
        guard authManager.isSignedIn else { return }
        await savedManager.loadSaved(userId: authManager.currentUser.id)
    }
}

struct SavedRestaurantCard: View {
    let restaurant: Restaurant
    @Environment(SavedRestaurantsManager.self) private var savedManager
    @Environment(LikesManager.self) private var likesManager
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Restaurant image
            Rectangle()
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

                        RestaurantMetaInfo(restaurant: restaurant)
                    }

                    Spacer()

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            savedManager.toggleSave(
                                restaurant,
                                by: authManager.currentUser.id
                            )
                        }
                    } label: {
                        Image(systemName: "bookmark.fill")
                            .font(.title3)
                            .foregroundStyle(.primary)
                    }
                }

                RatingBadge(rating: restaurant.rating, font: .subheadline)
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
