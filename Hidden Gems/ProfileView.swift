//
//  ProfileView.swift
//  Hidden Gems
//
//  Created by Divine Davis on 3/16/26.
//

import SwiftUI

struct ProfileView: View {
    var user: User? = nil // Optional user parameter - if nil, show current user
    @State private var currentUser = User.sarah
    @State private var myRecommendations: [Recommendation] = []
    @Environment(SavedRestaurantsManager.self) private var savedManager
    @Environment(LikesManager.self) private var likesManager
    
    private var displayUser: User {
        user ?? currentUser
    }
    
    private var isOwnProfile: Bool {
        user == nil || user?.id == currentUser.id
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Profile Header
                VStack(spacing: 12) {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 100, height: 100)
                        .overlay {
                            Image(systemName: "person.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.gray)
                        }
                    
                    VStack(spacing: 4) {
                        Text(displayUser.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(displayUser.username)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack(spacing: 40) {
                        StatView(count: displayUser.followersCount, label: "Followers")
                        StatView(count: displayUser.followingCount, label: "Following")
                        StatView(count: myRecommendations.count, label: "Recommendations")
                    }
                    .padding(.top, 8)
                    
                    if isOwnProfile {
                        Button {
                            // Edit profile action
                        } label: {
                            Text("Edit Profile")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray5))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 40)
                    } else {
                        Button {
                            // Follow action
                        } label: {
                            Text("Follow")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.accentColor)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .padding(.horizontal, 40)
                    }
                }
                .padding(.top)
                
                Divider()
                    .padding(.horizontal)
                
                // Recommendations Section
                VStack(alignment: .leading, spacing: 12) {
                    Text(isOwnProfile ? "My Recommendations" : "Recommendations")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    if myRecommendations.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "fork.knife")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            
                            Text("No recommendations yet")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            if isOwnProfile {
                                Button {
                                    // Add recommendation action
                                } label: {
                                    Text("Add Your First Recommendation")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(Color.accentColor)
                                        .foregroundStyle(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ], spacing: 12) {
                            ForEach(myRecommendations) { recommendation in
                                ProfileRecommendationCard(recommendation: recommendation)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .navigationTitle(isOwnProfile ? "Profile" : displayUser.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isOwnProfile {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        // Settings action
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
        .onAppear {
            loadRecommendations()
        }
    }
    
    private func loadRecommendations() {
        myRecommendations = Recommendation.samples.filter { $0.user.id == displayUser.id }
    }
}

struct ProfileRecommendationCard: View {
    let recommendation: Recommendation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(.gray)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(recommendation.restaurant.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                RatingBadge(rating: recommendation.restaurant.rating, font: .caption2)
            }
            .padding(8)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

#Preview {
    ProfileView()
}
