//
//  ProfileView.swift
//  Hidden Gems
//
//  Created by Divine Davis on 3/16/26.
//

import SwiftUI
import Supabase

struct ProfileView: View {
    var user: User? = nil // Optional user parameter - if nil, show current user
    @State private var myRecommendations: [Recommendation] = []
    @State private var showingSettings = false
    @Environment(SavedRestaurantsManager.self) private var savedManager
    @Environment(LikesManager.self) private var likesManager
    @Environment(FollowManager.self) private var followManager
    @Environment(AuthManager.self) private var authManager
    @Environment(RecommendationsManager.self) private var recommendationsManager

    private var displayUser: User {
        user ?? authManager.currentUser
    }

    private var isOwnProfile: Bool {
        user == nil || user?.id == authManager.currentUser.id
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
                        let isFollowing = followManager.isFollowing(displayUser)
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                followManager.toggleFollow(
                                    displayUser,
                                    by: authManager.currentUser.id
                                )
                            }
                        } label: {
                            Text(isFollowing ? "Following" : "Follow")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(isFollowing ? Color(.systemGray5) : Color.accentColor)
                                .foregroundStyle(isFollowing ? Color.primary : Color.white)
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
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
        .confirmationDialog("Settings", isPresented: $showingSettings) {
            Button("Log Out", role: .destructive) {
                authManager.signOut()
            }
            Button("Cancel", role: .cancel) { }
        }
        .task(id: displayUser.id) {
            await loadRecommendations()
        }
    }

    /// Fetches this profile's posts directly from the `feed` view so
    /// the list is populated even when the global feed tab hasn't been
    /// visited yet (or when viewing another user's profile).
    private func loadRecommendations() async {
        let targetId = displayUser.id
        do {
            let posts: [SupabaseFeedPost] = try await supabase
                .from("feed")
                .select()
                .eq("user_id", value: targetId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value
            myRecommendations = posts.map { $0.toRecommendation() }
        } catch {
            debugLog("Profile recs fetch error", error)
            myRecommendations = recommendationsManager.recommendations
                .filter { $0.user.id == targetId }
        }
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
